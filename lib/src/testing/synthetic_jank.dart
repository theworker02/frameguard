import 'package:flutter/scheduler.dart';

/// Test-only utilities that deliberately create slow frames / rebuild pressure.
///
/// Keep out of production code paths.
class SyntheticJank {
  SyntheticJank._();

  /// Blocks the current isolate for [duration] (CPU stall).
  static void cpu({Duration duration = const Duration(milliseconds: 30)}) {
    final sw = Stopwatch()..start();
    while (sw.elapsed < duration) {
      // Busy-wait to occupy the UI isolate.
    }
  }

  /// Schedules [count] post-frame callbacks that each do light work —
  /// useful to simulate rebuild/callback bursts in tests.
  static void rebuildBurst({int count = 20}) {
    for (var i = 0; i < count; i++) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // Touch a small amount of work.
        final list = List<int>.generate(100, (j) => j * i);
        list.sort();
      });
    }
  }

  /// Nested layout stress: builds a tall column of boxes (caller mounts it).
  static List<int> heavyLayoutIndices({int count = 200}) =>
      List<int>.generate(count, (i) => i);
}
