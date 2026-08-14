import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/core/frameguard.dart';
import 'package:frameguard/src/core/version.dart';
import 'package:frameguard/src/diagnostics/explainability.dart';
import 'package:frameguard/src/environment/build_mode.dart';
import 'package:frameguard/src/environment/device_metadata_capture.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/budget_evaluation.dart';
import 'package:frameguard/src/metrics/frame_sample.dart';
import 'package:frameguard/src/metrics/frame_stats.dart';
import 'package:frameguard/src/metrics/image_diagnostics.dart';
import 'package:frameguard/src/metrics/jank.dart';
import 'package:frameguard/src/metrics/region_stats.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:frameguard/src/tracing/marker.dart';
import 'package:frameguard/src/tracing/session_options.dart';
import 'package:frameguard/src/tracing/task.dart';
import 'package:frameguard/src/tracing/trace.dart';

export 'package:frameguard/src/metrics/image_diagnostics.dart';
export 'package:frameguard/src/metrics/region_stats.dart';
export 'session_options.dart';

/// An active performance capture session.
///
/// Created via [FrameGuard.startSession]. Call [stop] to produce a
/// [FrameGuardReport].
class FrameGuardSession {
  /// Creates a session. Prefer [FrameGuard.startSession].
  FrameGuardSession({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.options,
    required Duration frameBudget,
    required JankPolicy jankPolicy,
    required double refreshRateHz,
    required bool refreshRateFallback,
    this.budget,
  })  : _frameBudget = frameBudget,
        _jankPolicy = jankPolicy,
        _refreshRateHz = refreshRateHz,
        _refreshRateFallback = refreshRateFallback;

  /// Stable session ID for correlating logs and artifacts.
  final String id;

  /// Human-readable scenario name.
  final String name;

  /// When the session started.
  final DateTime startedAt;

  /// Capture options.
  final FrameGuardSessionOptions options;

  /// Optional budget evaluated when stopping.
  final FrameBudget? budget;

  final Duration _frameBudget;
  final JankPolicy _jankPolicy;
  final double _refreshRateHz;
  final bool _refreshRateFallback;

  final ListQueue<FrameSample> _frames = ListQueue();
  final List<FrameSample> _warmupFrames = [];
  final List<FrameGuardMarker> _markers = [];
  final List<FrameGuardTraceResult> _traces = [];
  final List<TaskMeasurement> _tasks = [];
  final Map<String, RegionStatsAccumulator> _regions = {};
  final Map<String, num> _customMetrics = {};
  final List<ImageWarning> _imageWarnings = [];
  ImageCacheSnapshot? _imageCacheSnapshot;

  var _frameCounter = 0;
  var _warmupFrameCount = 0;
  var _stopped = false;
  var _measuring = false;
  var _stableHealthyStreak = 0;
  TimingsCallback? _timingsCallback;
  DateTime? _warmupEndsAt;

  /// Whether the session is still open.
  bool get isOpen => !_stopped;

  /// Frames captured so far (post-warmup).
  List<FrameSample> get frames => List.unmodifiable(_frames);

  /// Starts listening to frame timings. Called by FrameGuard.
  void attach() {
    _warmupEndsAt = options.warmup > Duration.zero
        ? startedAt.add(options.warmup)
        : startedAt;
    if (options.waitForStableFrames <= 0) {
      _measuring = true;
    }
    if (options.captureFrameTimings) {
      _timingsCallback = _onTimings;
      SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_stopped) return;
    final now = DateTime.now();
    for (final timing in timings) {
      final build = timing.buildDuration;
      final raster = timing.rasterDuration;
      // Prefer totalSpan when available; fall back to build+raster.
      final total = timing.totalSpan;
      final vsync = timing.vsyncOverhead;

      final severity = _jankPolicy.classify(total, _frameBudget);
      final janky = JankPolicy.isJanky(severity);
      final bottleneck = FrameSample.classifyBottleneck(
        build: build,
        raster: raster,
      );

      final inWarmupWindow = now.isBefore(_warmupEndsAt ?? startedAt) ||
          _warmupFrameCount < options.warmupFrames;

      if (!_measuring) {
        if (!janky) {
          _stableHealthyStreak++;
          if (_stableHealthyStreak >= options.waitForStableFrames) {
            _measuring = true;
          }
        } else {
          _stableHealthyStreak = 0;
        }
        continue;
      }

      _frameCounter++;
      final sample = FrameSample(
        frameNumber: _frameCounter,
        buildDuration: build,
        rasterDuration: raster,
        totalDuration: total,
        vsyncOverhead: vsync,
        timestamp: now,
        severity: severity,
        janky: janky,
        bottleneck: bottleneck,
        eventIds: _markersOverlapping(now),
      );

      if (inWarmupWindow) {
        _warmupFrameCount++;
        if (_warmupFrames.length < 256) {
          _warmupFrames.add(sample);
        }
        continue;
      }

      _frames.addLast(sample);
      if (_frames.length > options.maxFrames) {
        if (options.ringBuffer) {
          _frames.removeFirst();
        } else {
          _frames.removeLast();
        }
      }

      // Notify region rebuild frame ticks.
      for (final region in _regions.values) {
        region.onFrame();
      }
    }
  }

  List<String> _markersOverlapping(DateTime frameTime) {
    // Markers within Â±8ms of the frame timestamp.
    const window = Duration(milliseconds: 8);
    return _markers
        .where(
          (m) => m.timestamp.difference(frameTime).abs() <= window,
        )
        .map((m) => m.id)
        .toList(growable: false);
  }

  /// Records a marker into this session.
  void addMarker(FrameGuardMarker marker) {
    _ensureOpen();
    _markers.add(marker);
  }

  /// Records a completed trace.
  void addTrace(FrameGuardTraceResult trace) {
    _ensureOpen();
    _traces.add(trace);
  }

  /// Records a task measurement.
  void addTask(TaskMeasurement task) {
    _ensureOpen();
    _tasks.add(task);
  }

  /// Attaches a custom metric.
  void addMetric(String name, num value) {
    _ensureOpen();
    _customMetrics[name] = value;
  }

  /// Ensures a region accumulator exists and returns it.
  RegionStatsAccumulator region(String name) {
    return _regions.putIfAbsent(name, () => RegionStatsAccumulator(name));
  }

  /// Records an image warning.
  void addImageWarning(ImageWarning warning) {
    if (!options.captureImages) return;
    _imageWarnings.add(warning);
  }

  /// Updates image cache snapshot.
  void updateImageCache(ImageCacheSnapshot snapshot) {
    if (!options.captureImages) return;
    _imageCacheSnapshot = snapshot;
  }

  /// Counts overlapping slow frames for a time window.
  int countOverlappingSlowFrames(DateTime start, DateTime end) {
    return _frames
        .where(
          (f) =>
              f.janky &&
              !f.timestamp.isBefore(start) &&
              !f.timestamp.isAfter(end),
        )
        .length;
  }

  /// Stops capture and builds a structured report.
  Future<FrameGuardReport> stop() async {
    if (_stopped) {
      throw SessionClosedException(id);
    }
    _stopped = true;
    if (_timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback!);
      _timingsCallback = null;
    }

    // Sample image cache if enabled.
    if (options.captureImages) {
      try {
        final cache = PaintingBinding.instance.imageCache;
        _imageCacheSnapshot ??= ImageCacheSnapshot(
          currentEntries: cache.currentSize,
          currentBytes: cache.currentSizeBytes,
          liveEntries: cache.liveImageCount,
          peakEntries: cache.currentSize,
          peakBytes: cache.currentSizeBytes,
          evictions: 0,
        );
      } catch (_) {
        // Unavailable in some test bindings.
      }
    }

    final frameList = _frames.toList(growable: false);
    final stats = FrameStats.compute(frameList);
    final regionStats =
        _regions.values.map((r) => r.toStats()).toList(growable: false);

    final metadata = captureDeviceMetadata(
      refreshRateHz: _refreshRateHz,
      refreshRateFallback: _refreshRateFallback,
    );

    final effectiveBudget = budget ?? FrameGuard.instance.config.defaultBudget;
    BudgetEvaluation? evaluation;
    if (effectiveBudget != null) {
      evaluation = BudgetEvaluation.evaluate(stats, effectiveBudget);
    }

    final report = FrameGuardReport(
      schemaVersion: FrameGuardReport.currentSchemaVersion,
      id: id,
      scenario: name,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      frameguardVersion: frameGuardPackageVersion,
      device: metadata,
      frameBudgetTarget: _frameBudget,
      refreshRateHz: _refreshRateHz,
      refreshRateFallback: _refreshRateFallback,
      frames: frameList,
      warmupFrameCount: _warmupFrames.length,
      stats: stats,
      markers: List.unmodifiable(_markers),
      traces: List.unmodifiable(_traces),
      tasks: List.unmodifiable(_tasks),
      regions: regionStats,
      customMetrics: Map.unmodifiable(_customMetrics),
      imageWarnings: List.unmodifiable(_imageWarnings),
      imageCache: _imageCacheSnapshot,
      budget: effectiveBudget,
      budgetEvaluation: evaluation,
      debugModeWarning: debugModeWarning(metadata.buildMode),
      sessionOptions: options,
    );

    FrameGuard.instance.clearActiveSession(this);

    // Attach explanation after construction (needs full report).
    return report.copyWith(
      explanation: ScenarioExplanation.fromReport(report),
    );
  }

  void _ensureOpen() {
    if (_stopped) throw SessionClosedException(id);
  }
}
