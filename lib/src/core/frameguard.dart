import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:frameguard/src/core/capabilities.dart';
import 'package:frameguard/src/core/config.dart';
import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/core/sampling_mode.dart';
import 'package:frameguard/src/core/version.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:frameguard/src/tracing/marker.dart';
import 'package:frameguard/src/tracing/session.dart';
import 'package:frameguard/src/tracing/task.dart';
import 'package:frameguard/src/tracing/trace.dart';

/// Runtime performance violation emitted by [FrameGuard.onViolation].
class FrameGuardViolation {
  /// Creates a violation.
  const FrameGuardViolation({
    required this.message,
    required this.sessionId,
    this.metric,
    this.actual,
    this.limit,
  });

  /// Human-readable message.
  final String message;

  /// Related session ID.
  final String sessionId;

  /// Optional metric name.
  final String? metric;

  /// Optional actual value description.
  final String? actual;

  /// Optional limit description.
  final String? limit;
}

/// Central entry point for FrameGuard.
///
/// Call [initialize] once at app start, then use [startSession], [trace],
/// [mark], and [measureTask]. Completely local — no telemetry.
class FrameGuard {
  FrameGuard._();

  /// Package version embedded in reports.
  static const String packageVersion = frameGuardPackageVersion;

  static FrameGuard? _instance;
  static final _violationController =
      StreamController<FrameGuardViolation>.broadcast();

  /// Singleton instance after [initialize].
  static FrameGuard get instance {
    final i = _instance;
    if (i == null) throw FrameGuardNotInitializedException();
    return i;
  }

  /// Whether [initialize] has been called.
  static bool get isInitialized => _instance != null;

  /// Stream of runtime budget violations (no automatic telemetry).
  static Stream<FrameGuardViolation> get onViolation =>
      _violationController.stream;

  /// Initializes FrameGuard. Safe to call once; subsequent calls replace config
  /// only if [force] is true.
  static void initialize({
    FrameGuardConfig config = const FrameGuardConfig(),
    bool force = false,
  }) {
    if (_instance != null && !force) return;
    _instance = FrameGuard._()
      .._config = config
      .._capabilities = FrameGuardCapabilities.detect();
    onTraceCompleted = _instance!.completeTrace;
  }

  /// Resets global state. Intended for tests and benchmarks.
  static void reset() {
    onTraceCompleted = null;
    _instance?._activeSession = null;
    _instance?._traceStack.clear();
    _instance = null;
  }

  late FrameGuardConfig _config;
  late FrameGuardCapabilities _capabilities;
  FrameGuardSession? _activeSession;
  final List<FrameGuardTrace> _traceStack = [];
  final _random = Random();

  /// Active configuration.
  FrameGuardConfig get config => _config;

  /// Detected capabilities.
  FrameGuardCapabilities get capabilities => _capabilities;

  /// Currently active session, if any.
  FrameGuardSession? get activeSession => _activeSession;

  /// Starts a named performance session.
  ///
  /// Captures frame timings via `SchedulerBinding.addTimingsCallback`.
  /// Overhead is intentionally low; prefer [SamplingMode.lightweight] when
  /// embedding in production builds.
  static FrameGuardSession startSession({
    required String name,
    FrameGuardSessionOptions? options,
    FrameBudget? budget,
    int? warmupFrames,
    Duration? warmup,
  }) {
    final fg = instance;
    final opts = options ??
        FrameGuardSessionOptions.fromSamplingMode(
          fg._config.samplingMode,
          warmup: warmup ?? Duration.zero,
          warmupFrames: warmupFrames ?? 0,
          maxFrames: fg._config.maxFrames,
        );

    final rate = fg._config.refreshRate;
    final hz = rate.effectiveHz(fallbackHz: fg._config.refreshRateFallbackHz);
    final frameBudget = rate.frameBudget(
      fallbackHz: fg._config.refreshRateFallbackHz,
    );

    final session = FrameGuardSession(
      id: fg._newId('sess'),
      name: name,
      startedAt: DateTime.now(),
      options: opts,
      frameBudget: frameBudget,
      jankPolicy: fg._config.jankPolicy,
      refreshRateHz: hz,
      refreshRateFallback: rate.usedFallback,
      budget: budget ?? fg._config.defaultBudget,
    );
    session.attach();
    fg._activeSession = session;
    if (opts.captureTimelineEvents) {
      developer.Timeline.instantSync(
        'frameguard.session.start',
        arguments: {'id': session.id, 'name': name},
      );
    }
    return session;
  }

  /// Runs [body] inside a named session and returns the finished report.
  ///
  /// Convenience over [startSession] + [FrameGuardSession.stop]. Always stops
  /// the session even if [body] throws.
  static Future<FrameGuardReport> runSession({
    required String name,
    required Future<void> Function() body,
    FrameGuardSessionOptions? options,
    FrameBudget? budget,
    int? warmupFrames,
    Duration? warmup,
  }) async {
    final session = startSession(
      name: name,
      options: options,
      budget: budget,
      warmupFrames: warmupFrames,
      warmup: warmup,
    );
    Object? error;
    StackTrace? stack;
    try {
      await body();
    } catch (e, st) {
      error = e;
      stack = st;
    }
    final report = await session.stop();
    if (error != null) {
      Error.throwWithStackTrace(error, stack ?? StackTrace.current);
    }
    return report;
  }

  /// Begins a named interaction trace (supports nesting).
  static FrameGuardTrace beginTrace(String name) {
    final fg = instance;
    final parent = fg._traceStack.isEmpty ? null : fg._traceStack.last;
    final trace = createTrace(
      id: fg._newId('trace'),
      name: name,
      parentId: parent?.id,
    );
    parent?.attachChild(trace.id);
    fg._traceStack.add(trace);
    return trace;
  }

  /// Runs [body] inside a named trace and ends it automatically.
  static Future<T> trace<T>(
    String name,
    Future<T> Function() body,
  ) async {
    final t = beginTrace(name);
    try {
      return await body();
    } finally {
      await t.end();
    }
  }

  /// Completes a trace and records it on the active session.
  void completeTrace(FrameGuardTrace trace) {
    if (_traceStack.isNotEmpty && _traceStack.last.id == trace.id) {
      _traceStack.removeLast();
    } else {
      _traceStack.removeWhere((t) => t.id == trace.id);
    }
    final result = FrameGuardTraceResult.fromTrace(trace);
    _activeSession?.addTrace(result);
  }

  /// Emits a custom diagnostic marker.
  static FrameGuardMarker mark(
    String name, {
    Map<String, Object?> metadata = const {},
  }) {
    final fg = instance;
    final parent = fg._traceStack.isEmpty ? null : fg._traceStack.last;
    final marker = FrameGuardMarker(
      id: fg._newId('evt'),
      name: name,
      timestamp: DateTime.now(),
      metadata: metadata,
      traceId: parent?.id,
    );
    noteMarkerOnTrace(parent, marker);
    fg._activeSession?.addMarker(marker);
    if (fg._config.samplingMode.captureTimelineEvents) {
      developer.Timeline.instantSync(
        'frameguard.mark.$name',
        arguments: {'id': marker.id, ...metadata},
      );
    }
    return marker;
  }

  /// Records a custom numeric metric on the active session.
  static void metric(String name, num value) {
    instance._activeSession?.addMetric(name, value);
  }

  /// Measures synchronous (or async) work and correlates with slow frames.
  static Future<T> measureTask<T>(
    String name,
    FutureOr<T> Function() body, {
    Duration? budget,
  }) async {
    final fg = instance;
    final limit = budget ??
        fg._activeSession?.options.syncTaskBudget ??
        const Duration(milliseconds: 8);
    final start = DateTime.now();
    developer.Timeline.startSync('frameguard.task.$name');
    try {
      final result = await body();
      return result;
    } finally {
      developer.Timeline.finishSync();
      final end = DateTime.now();
      final duration = end.difference(start);
      final overlapping =
          fg._activeSession?.countOverlappingSlowFrames(start, end) ?? 0;
      final exceeded = duration > limit;
      final measurement = TaskMeasurement(
        id: fg._newId('task'),
        name: name,
        duration: duration,
        startedAt: start,
        endedAt: end,
        overlappingSlowFrames: overlapping,
        exceededBudget: exceeded,
        budget: limit,
      );
      fg._activeSession?.addTask(measurement);
      if (exceeded) {
        _violationController.add(
          FrameGuardViolation(
            message: 'Task $name exceeded UI-thread budget: '
                '${(duration.inMicroseconds / 1000).toStringAsFixed(1)} ms > '
                '${(limit.inMicroseconds / 1000).toStringAsFixed(1)} ms',
            sessionId: fg._activeSession?.id ?? 'none',
            metric: 'sync_task',
            actual: '${duration.inMilliseconds}ms',
            limit: '${limit.inMilliseconds}ms',
          ),
        );
      }
    }
  }

  /// Emits a runtime violation (used by overlay / budget watchers).
  static void reportViolation(FrameGuardViolation violation) {
    _violationController.add(violation);
  }

  /// Clears the active session reference after stop.
  void clearActiveSession(FrameGuardSession session) {
    if (_activeSession?.id == session.id) {
      _activeSession = null;
    }
  }

  String _newId(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final r = _random.nextInt(1 << 32).toRadixString(16);
    return '$prefix-$ts-$r';
  }
}
