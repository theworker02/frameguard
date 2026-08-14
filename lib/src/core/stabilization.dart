import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:frameguard/src/metrics/jank.dart';

/// Waits until the UI appears stable before measurement.
///
/// Uses documented Flutter APIs only:
/// - consecutive healthy [FrameTiming]s
/// - post-frame callbacks / scheduled frames
class Stabilization {
  /// Creates a stabilization waiter.
  Stabilization({
    this.healthyFramesRequired = 5,
    this.frameBudget = const Duration(milliseconds: 16),
    this.jankPolicy = const JankPolicy(),
    this.timeout = const Duration(seconds: 5),
  });

  /// Consecutive healthy frames required.
  final int healthyFramesRequired;

  /// Frame budget for health classification.
  final Duration frameBudget;

  /// Jank policy.
  final JankPolicy jankPolicy;

  /// Maximum wait before giving up (returns false).
  final Duration timeout;

  /// Waits for [healthyFramesRequired] consecutive healthy frames.
  ///
  /// Returns `true` if stabilized, `false` on timeout.
  Future<bool> waitForHealthyFrames() async {
    final completer = Completer<bool>();
    var streak = 0;
    late final TimingsCallback callback;

    callback = (timings) {
      for (final t in timings) {
        final severity = jankPolicy.classify(t.totalSpan, frameBudget);
        if (JankPolicy.isJanky(severity)) {
          streak = 0;
        } else {
          streak++;
          if (streak >= healthyFramesRequired) {
            SchedulerBinding.instance.removeTimingsCallback(callback);
            if (!completer.isCompleted) completer.complete(true);
            return;
          }
        }
      }
    };

    SchedulerBinding.instance.addTimingsCallback(callback);
    SchedulerBinding.instance.scheduleFrame();

    final result = await Future.any<bool>([
      completer.future,
      Future<bool>.delayed(timeout, () => false),
    ]);

    if (!completer.isCompleted) {
      SchedulerBinding.instance.removeTimingsCallback(callback);
    }
    return result;
  }

  /// Yields a few frames, then optionally waits for healthy frames.
  Future<bool> waitUntilSettled({bool requireHealthyFrames = true}) async {
    for (var i = 0; i < 3; i++) {
      final c = Completer<void>();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!c.isCompleted) c.complete();
      });
      SchedulerBinding.instance.scheduleFrame();
      await c.future;
    }
    if (!requireHealthyFrames) return true;
    return waitForHealthyFrames();
  }
}
