import 'package:flutter/scheduler.dart';
import 'package:frameguard/src/core/frameguard.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/jank.dart';

/// Watches live frame timings and emits [FrameGuardViolation]s when budgets
/// are exceeded. Completely local — no telemetry.
///
/// Attach while developing; dispose when done. Does not send data anywhere.
class FrameGuardBudgetWatcher {
  /// Creates a watcher.
  FrameGuardBudgetWatcher({
    FrameBudget? budget,
    JankPolicy? jankPolicy,
    Duration? frameBudget,
    this.windowSize = 120,
  })  : _budget = budget,
        _jankPolicy = jankPolicy ?? const JankPolicy(),
        _frameBudget = frameBudget ?? const Duration(milliseconds: 16);

  final FrameBudget? _budget;
  final JankPolicy _jankPolicy;
  final Duration _frameBudget;

  /// Rolling window for rate/percentile checks.
  final int windowSize;

  TimingsCallback? _callback;
  final List<Duration> _totals = [];
  var _janky = 0;
  var _frames = 0;

  /// Starts listening.
  void start() {
    if (_callback != null) return;
    _callback = _onTimings;
    SchedulerBinding.instance.addTimingsCallback(_callback!);
  }

  /// Stops listening.
  void stop() {
    if (_callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_callback!);
      _callback = null;
    }
  }

  /// Alias for [stop].
  void dispose() => stop();

  void _onTimings(List<FrameTiming> timings) {
    final sessionId = FrameGuard.isInitialized
        ? (FrameGuard.instance.activeSession?.id ?? 'runtime')
        : 'runtime';

    for (final t in timings) {
      final total = t.totalSpan;
      _frames++;
      _totals.add(total);
      if (_totals.length > windowSize) {
        _totals.removeAt(0);
      }

      final severity = _jankPolicy.classify(total, _frameBudget);
      if (JankPolicy.isJanky(severity)) {
        _janky++;
        if (severity == JankSeverity.severe) {
          FrameGuard.reportViolation(
            FrameGuardViolation(
              message: 'Severe jank frame: '
                  '${(total.inMicroseconds / 1000).toStringAsFixed(1)} ms',
              sessionId: sessionId,
              metric: 'frame_severity',
              actual: severity.name,
            ),
          );
        }
      }

      final budget = _budget;
      if (budget?.maxFrameTime != null && total > budget!.maxFrameTime!) {
        FrameGuard.reportViolation(
          FrameGuardViolation(
            message: 'Frame exceeded maxFrameTime: '
                '${(total.inMicroseconds / 1000).toStringAsFixed(1)} ms > '
                '${(budget.maxFrameTime!.inMicroseconds / 1000).toStringAsFixed(1)} ms',
            sessionId: sessionId,
            metric: 'max_frame',
            actual: '${total.inMilliseconds}ms',
            limit: '${budget.maxFrameTime!.inMilliseconds}ms',
          ),
        );
      }
    }

    _checkWindow(sessionId);
  }

  void _checkWindow(String sessionId) {
    final budget = _budget;
    if (budget == null || _totals.isEmpty) return;

    if (budget.maxJankRate != null && _frames > 0) {
      final rate = _janky / _frames;
      if (rate > budget.maxJankRate!) {
        FrameGuard.reportViolation(
          FrameGuardViolation(
            message: 'Jank rate exceeded configured budget: '
                '${(rate * 100).toStringAsFixed(1)}% > '
                '${(budget.maxJankRate! * 100).toStringAsFixed(1)}%',
            sessionId: sessionId,
            metric: 'jank_rate',
            actual: '$rate',
            limit: '${budget.maxJankRate}',
          ),
        );
      }
    }

    if (budget.maxP99FrameTime != null && _totals.length >= 20) {
      final sorted = [..._totals]..sort();
      final idx = ((sorted.length - 1) * 0.99).round();
      final p99 = sorted[idx];
      if (p99 > budget.maxP99FrameTime!) {
        FrameGuard.reportViolation(
          FrameGuardViolation(
            message: 'P99 exceeded configured budget: '
                '${(p99.inMicroseconds / 1000).toStringAsFixed(1)} ms > '
                '${(budget.maxP99FrameTime!.inMicroseconds / 1000).toStringAsFixed(1)} ms',
            sessionId: sessionId,
            metric: 'p99',
            actual: '${p99.inMilliseconds}ms',
            limit: '${budget.maxP99FrameTime!.inMilliseconds}ms',
          ),
        );
      }
    }
  }
}
