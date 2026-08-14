import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';
import 'package:path/path.dart' as p;

/// Writes committed CLI fixtures. Run with:
/// `flutter test test/generate_fixtures_test.dart`
void main() {
  test('generate fixtures', () async {
    FrameGuard.initialize(
      config: FrameGuardConfig(
        refreshRate: const RefreshRate.hz(60),
        defaultBudget: FrameBudget.forRefreshRate(60, maxJankRate: 0.02),
      ),
      force: true,
    );
    addTearDown(FrameGuard.reset);

    final outDir = Directory('test/fixtures');
    await outDir.create(recursive: true);
    await Directory(p.join(outDir.path, 'baselines')).create(recursive: true);

    final healthy = _buildReport(
      scenario: 'healthy_scroll',
      id: 'sess-fixture-healthy',
      jankEvery: 50,
      budget: FrameBudget.forRefreshRate(
        60,
        maxJankRate: 0.05,
        maxJankFrames: 10,
        p99Multiplier: 2.5,
      ),
    );
    final regressing = _buildReport(
      scenario: 'catalog_scroll',
      id: 'sess-fixture-regress',
      jankEvery: 5,
      buildHeavy: true,
      budget: FrameBudget.forRefreshRate(
        60,
        maxJankRate: 0.02,
        maxJankFrames: 3,
      ),
    );
    final worse = _buildReport(
      scenario: 'healthy_scroll',
      id: 'sess-fixture-worse',
      jankEvery: 8,
      buildHeavy: true,
      budget: FrameBudget.forRefreshRate(
        60,
        maxJankRate: 0.05,
        maxJankFrames: 10,
        p99Multiplier: 2.5,
      ),
    );

    await healthy.writeJson(File(p.join(outDir.path, 'healthy_scroll.json')));
    await regressing
        .writeJson(File(p.join(outDir.path, 'catalog_scroll.json')));
    await worse
        .writeJson(File(p.join(outDir.path, 'healthy_scroll_worse.json')));
    await FrameGuardBaseline.fromReport(healthy).write(
      File(p.join(outDir.path, 'baselines', 'healthy_scroll.json')),
    );

    expect(
        File(p.join(outDir.path, 'healthy_scroll.json')).existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 1)));
}

FrameGuardReport _buildReport({
  required String scenario,
  required String id,
  required int jankEvery,
  required FrameBudget budget,
  bool buildHeavy = false,
}) {
  final started = DateTime.utc(2026, 8, 12, 18);
  final frames = <FrameSample>[];
  for (var i = 0; i < 100; i++) {
    final janky = i % jankEvery == 0;
    final build = Duration(
      milliseconds: janky ? (buildHeavy ? 28 : 8) : 4 + (i % 3),
    );
    final raster = Duration(
      milliseconds: janky ? (buildHeavy ? 4 : 22) : 2 + (i % 2),
    );
    final total = build + raster;
    final severity = const JankPolicy().classify(
      total,
      const Duration(milliseconds: 16),
    );
    frames.add(
      FrameSample(
        frameNumber: i,
        buildDuration: build,
        rasterDuration: raster,
        totalDuration: total,
        vsyncOverhead: Duration.zero,
        timestamp: started.add(Duration(milliseconds: i * 16)),
        severity: severity,
        janky: JankPolicy.isJanky(severity),
        bottleneck: FrameSample.classifyBottleneck(
          build: build,
          raster: raster,
        ),
      ),
    );
  }

  final stats = FrameStats.compute(frames);
  final evaluation = BudgetEvaluation.evaluate(stats, budget);
  final draft = FrameGuardReport(
    schemaVersion: FrameGuardReport.currentSchemaVersion,
    id: id,
    scenario: scenario,
    startedAt: started,
    endedAt: started.add(const Duration(seconds: 2)),
    frameguardVersion: FrameGuard.packageVersion,
    device: const DeviceMetadata(
      platform: 'android',
      buildMode: FrameGuardBuildMode.profile,
      refreshRateHz: 60,
      deviceModel: 'fixture',
      flutterVersion: '3.24.0',
      dartVersion: '3.5.0',
    ),
    frameBudgetTarget: const Duration(milliseconds: 16),
    refreshRateHz: 60,
    refreshRateFallback: false,
    frames: frames,
    warmupFrameCount: 0,
    stats: stats,
    markers: const [],
    traces: const [],
    tasks: const [],
    regions: [
      RegionStats(
        name: 'product_grid',
        rebuilds: buildHeavy ? 120 : 20,
        framesObserved: 100,
        averageRebuildsPerFrame: buildHeavy ? 1.2 : 0.2,
        peakRebuildsInFrame: buildHeavy ? 13 : 2,
      ),
    ],
    customMetrics: const {'fixture': 1},
    imageWarnings: const [],
    budget: budget,
    budgetEvaluation: evaluation,
  );
  return draft.copyWith(explanation: ScenarioExplanation.fromReport(draft));
}
