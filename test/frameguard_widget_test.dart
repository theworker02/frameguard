import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';
import 'package:frameguard/frameguard_test.dart';

void main() {
  tearDown(FrameGuard.reset);

  testWidgets('FrameGuardRegion counts rebuilds during session',
      (tester) async {
    FrameGuard.initialize();
    final session = FrameGuard.startSession(
      name: 'region_test',
      options: const FrameGuardSessionOptions(captureRebuilds: true),
    );

    var ticks = 0;
    await tester.pumpWidget(
      FrameGuardScope(
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return FrameGuardRegion(
                name: 'product_grid',
                child: TextButton(
                  onPressed: () => setState(() => ticks++),
                  child: Text('tap $ticks'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await tester.tap(find.byType(TextButton));
    await tester.pump();

    final report = await session.stop();
    final region = report.regions.where((r) => r.name == 'product_grid');
    expect(region, isNotEmpty);
    expect(region.first.rebuilds, greaterThanOrEqualTo(2));
  });

  testWidgets('FrameGuardTest.measure returns a report', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('hello'))),
    );

    final report = await FrameGuardTest.measure(
      tester,
      name: 'smoke',
      warmupFrames: 0,
      action: () async {
        await tester.pump();
        FrameGuard.mark('pumped');
      },
    );

    expect(report.scenario, 'smoke');
    expect(report.markers.any((m) => m.name == 'pumped'), isTrue);
  });

  testWidgets('matchers fail with diagnostic text', (tester) async {
    FrameGuard.initialize();
    final report = FrameGuardReport(
      schemaVersion: 1,
      id: 'x',
      scenario: 's',
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      frameguardVersion: '0.1.0',
      device: const DeviceMetadata(
        platform: 'test',
        buildMode: FrameGuardBuildMode.debug,
        refreshRateHz: 60,
      ),
      frameBudgetTarget: const Duration(milliseconds: 16),
      refreshRateHz: 60,
      refreshRateFallback: true,
      frames: [
        FrameSample(
          frameNumber: 1,
          buildDuration: const Duration(milliseconds: 40),
          rasterDuration: const Duration(milliseconds: 2),
          totalDuration: const Duration(milliseconds: 42),
          vsyncOverhead: Duration.zero,
          timestamp: DateTime.now(),
          severity: JankSeverity.severe,
          janky: true,
          bottleneck: FrameBottleneck.buildBound,
        ),
      ],
      warmupFrameCount: 0,
      stats: FrameStats.compute([
        FrameSample(
          frameNumber: 1,
          buildDuration: const Duration(milliseconds: 40),
          rasterDuration: const Duration(milliseconds: 2),
          totalDuration: const Duration(milliseconds: 42),
          vsyncOverhead: Duration.zero,
          timestamp: DateTime.now(),
          severity: JankSeverity.severe,
          janky: true,
          bottleneck: FrameBottleneck.buildBound,
        ),
      ]),
      markers: const [],
      traces: const [],
      tasks: const [],
      regions: const [],
      customMetrics: const {},
      imageWarnings: const [],
    );

    expect(report, isNot(hasNoSevereJank));
    expect(
      report,
      isNot(
        meetsFrameBudget(
          const FrameBudget(maxP95FrameTime: Duration(milliseconds: 16)),
        ),
      ),
    );
  });
}
