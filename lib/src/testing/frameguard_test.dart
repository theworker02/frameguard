import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/src/core/frameguard.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:frameguard/src/tracing/session.dart';

/// Test helpers for `flutter_test` and `integration_test`.
class FrameGuardTest {
  FrameGuardTest._();

  /// Measures [action] under a FrameGuard session and returns the report.
  ///
  /// Ensures FrameGuard is initialized. Prefer profile/release for meaningful
  /// timings; debug mode still works but reports a warning.
  static Future<FrameGuardReport> measure(
    WidgetTester tester, {
    required String name,
    required Future<void> Function() action,
    FrameGuardSessionOptions? options,
    FrameBudget? budget,
    int warmupFrames = 5,
    Duration? warmup,
  }) async {
    if (!FrameGuard.isInitialized) {
      FrameGuard.initialize();
    }

    final session = FrameGuard.startSession(
      name: name,
      options: options,
      budget: budget,
      warmupFrames: warmupFrames,
      warmup: warmup,
    );

    await action();
    // Allow pending frames to flush into timings callbacks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final report = await session.stop();
    FrameGuard.instance.clearActiveSession(session);
    return report;
  }

  /// Runs [action] after [warmup] pumps, then measures.
  static Future<FrameGuardReport> measureSettled(
    WidgetTester tester, {
    required String name,
    required Future<void> Function() action,
    FrameBudget? budget,
    int settlePumps = 10,
  }) async {
    for (var i = 0; i < settlePumps; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return measure(
      tester,
      name: name,
      action: action,
      budget: budget,
      warmupFrames: 0,
    );
  }
}
