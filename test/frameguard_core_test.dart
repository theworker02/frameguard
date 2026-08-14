import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';

void main() {
  tearDown(FrameGuard.reset);

  group('Percentiles', () {
    test('computes p50/p95/p99', () {
      final values = [
        for (var i = 1; i <= 100; i++) Duration(milliseconds: i),
      ];
      expect(
        Percentiles.percentile(values, 50).inMilliseconds,
        closeTo(50.5, 0.6),
      );
      expect(Percentiles.percentile(values, 95).inMilliseconds, closeTo(95, 1));
      expect(Percentiles.percentile(values, 99).inMilliseconds, closeTo(99, 1));
    });

    test('handles empty', () {
      expect(Percentiles.mean(const []), Duration.zero);
      expect(Percentiles.percentile(const [], 50), Duration.zero);
    });
  });

  group('JankPolicy', () {
    const policy = JankPolicy();
    const budget = Duration(milliseconds: 8);

    test('classifies severities', () {
      expect(
        policy.classify(const Duration(milliseconds: 7), budget),
        JankSeverity.healthy,
      );
      expect(
        policy.classify(const Duration(milliseconds: 12), budget),
        JankSeverity.minor,
      );
      expect(
        policy.classify(const Duration(milliseconds: 20), budget),
        JankSeverity.major,
      );
      expect(
        policy.classify(const Duration(milliseconds: 40), budget),
        JankSeverity.severe,
      );
    });
  });

  group('FrameBottleneck', () {
    test('build-bound when build dominates', () {
      expect(
        FrameSample.classifyBottleneck(
          build: const Duration(milliseconds: 20),
          raster: const Duration(milliseconds: 4),
        ),
        FrameBottleneck.buildBound,
      );
    });

    test('raster-bound when raster dominates', () {
      expect(
        FrameSample.classifyBottleneck(
          build: const Duration(milliseconds: 3),
          raster: const Duration(milliseconds: 25),
        ),
        FrameBottleneck.rasterBound,
      );
    });

    test('insufficient when both tiny', () {
      expect(
        FrameSample.classifyBottleneck(
          build: const Duration(milliseconds: 1),
          raster: const Duration(milliseconds: 1),
        ),
        FrameBottleneck.insufficientEvidence,
      );
    });
  });

  group('FrameStats', () {
    test('computes summary metrics', () {
      final frames = [
        for (var i = 0; i < 100; i++)
          FrameSample(
            frameNumber: i,
            buildDuration: Duration(milliseconds: 4 + (i % 3)),
            rasterDuration: const Duration(milliseconds: 3),
            totalDuration: Duration(milliseconds: 7 + (i % 3)),
            vsyncOverhead: Duration.zero,
            timestamp: DateTime.fromMillisecondsSinceEpoch(i * 16),
            severity: i == 50 ? JankSeverity.major : JankSeverity.healthy,
            janky: i == 50,
            bottleneck: FrameBottleneck.buildBound,
          ),
      ];
      // Make one clearly janky.
      frames[50] = FrameSample(
        frameNumber: 50,
        buildDuration: const Duration(milliseconds: 30),
        rasterDuration: const Duration(milliseconds: 4),
        totalDuration: const Duration(milliseconds: 34),
        vsyncOverhead: Duration.zero,
        timestamp: DateTime.fromMillisecondsSinceEpoch(800),
        severity: JankSeverity.major,
        janky: true,
        bottleneck: FrameBottleneck.buildBound,
      );

      final stats = FrameStats.compute(frames);
      expect(stats.totalFrames, 100);
      expect(stats.jankyFrames, 1);
      expect(stats.jankRate, closeTo(0.01, 0.0001));
      expect(stats.max.inMilliseconds, 34);
      expect(stats.buildBoundFrames, greaterThan(0));
    });
  });

  group('FrameBudget', () {
    test('forRefreshRate sets ~8.33ms at 120Hz', () {
      final budget = FrameBudget.forRefreshRate(120);
      expect(budget.maxP95FrameTime!.inMicroseconds, closeTo(8333, 5));
    });

    test('rejects invalid jank rate', () {
      expect(
        () => const FrameBudget(maxJankRate: 2).validate(),
        throwsA(isA<InvalidBudgetException>()),
      );
    });
  });

  group('BudgetEvaluation', () {
    test('fails when p95 exceeds limit', () {
      final stats = FrameStats.compute([
        for (var i = 0; i < 20; i++)
          FrameSample(
            frameNumber: i,
            buildDuration: const Duration(milliseconds: 20),
            rasterDuration: const Duration(milliseconds: 2),
            totalDuration: const Duration(milliseconds: 22),
            vsyncOverhead: Duration.zero,
            timestamp: DateTime.fromMillisecondsSinceEpoch(i * 16),
            severity: JankSeverity.major,
            janky: true,
            bottleneck: FrameBottleneck.buildBound,
          ),
      ]);
      final eval = BudgetEvaluation.evaluate(
        stats,
        const FrameBudget(maxP95FrameTime: Duration(milliseconds: 16)),
      );
      expect(eval.passed, isFalse);
      expect(eval.failures.any((f) => f.name == 'p95'), isTrue);
    });
  });

  group('Baseline comparison', () {
    test('detects p95 regression', () {
      FrameGuard.initialize();
      final baseline = const FrameGuardBaseline(
        schemaVersion: 1,
        scenario: 'catalog_scroll',
        device: DeviceMetadata(
          platform: 'android',
          buildMode: FrameGuardBuildMode.profile,
          refreshRateHz: 120,
        ),
        metrics: BaselineMetrics(
          p50FrameMs: 6,
          p95FrameMs: 12.8,
          p99FrameMs: 18.1,
          maxFrameMs: 30,
          jankRate: 0.007,
          jankyFrames: 5,
          averageBuildMs: 4,
          averageRasterMs: 3,
        ),
      );

      final current = _syntheticReport(
        scenario: 'catalog_scroll',
        totalMs: 17,
        jankEvery: 10,
      );

      final result = const FrameGuardCompare().compareReportToBaseline(
        current,
        baseline,
      );
      expect(result.isRegression, isTrue);
      expect(result.deltas.any((d) => d.name == 'P95' && d.regressed), isTrue);
    });
  });

  group('JSON round-trip', () {
    test('encode/decode preserves stats', () {
      FrameGuard.initialize();
      final report = _syntheticReport(scenario: 'roundtrip', totalMs: 10);
      final json = report.toJson();
      final restored = FrameGuardReport.fromJson(json);
      expect(restored.scenario, 'roundtrip');
      expect(restored.stats.totalFrames, report.stats.totalFrames);
      expect(restored.schemaVersion, FrameGuardReport.currentSchemaVersion);
    });
  });

  group('Aggregate', () {
    test('median across runs', () {
      FrameGuard.initialize();
      final reports = [
        _syntheticReport(scenario: 'a', totalMs: 10),
        _syntheticReport(scenario: 'a', totalMs: 12),
        _syntheticReport(scenario: 'a', totalMs: 20),
      ];
      final agg = FrameGuardAggregate.fromReports(reports);
      expect(agg.reports.length, 3);
      expect(agg.bestRun.stats.p95 <= agg.worstRun.stats.p95, isTrue);
    });
  });

  group('Explainability', () {
    test('flags build-bound primary finding', () {
      FrameGuard.initialize();
      final report = _syntheticReport(
        scenario: 'rebuild_storm',
        totalMs: 30,
        buildMs: 26,
        rasterMs: 4,
        jankEvery: 1,
      );
      final explanation = ScenarioExplanation.fromReport(report);
      expect(explanation.primaryFinding.toLowerCase(), contains('build'));
      expect(explanation.evidence, isNotEmpty);
    });
  });

  group('Drift', () {
    test('detects gradual regression', () {
      final baselines = [
        for (var i = 0; i < 4; i++)
          FrameGuardBaseline(
            schemaVersion: 1,
            scenario: 's',
            device: const DeviceMetadata(
              platform: 'android',
              buildMode: FrameGuardBuildMode.profile,
              refreshRateHz: 60,
            ),
            metrics: BaselineMetrics(
              p50FrameMs: 8,
              p95FrameMs: 10.8 + i * 1.3,
              p99FrameMs: 16,
              maxFrameMs: 40,
              jankRate: 0.01,
              jankyFrames: 2,
              averageBuildMs: 5,
              averageRasterMs: 4,
            ),
            createdAt: DateTime(2026, 1, 1 + i),
          ),
      ];
      final drift = BaselineDrift.p95(baselines);
      expect(drift.gradualRegression, isTrue);
    });
  });
}

FrameGuardReport _syntheticReport({
  required String scenario,
  required int totalMs,
  int buildMs = 8,
  int rasterMs = 4,
  int jankEvery = 20,
  int count = 50,
}) {
  final budget = const Duration(milliseconds: 16);
  final policy = const JankPolicy();
  final frames = <FrameSample>[
    for (var i = 0; i < count; i++)
      () {
        final janky = jankEvery > 0 && i % jankEvery == 0;
        final total = Duration(milliseconds: janky ? totalMs : 8);
        final build = Duration(milliseconds: janky ? buildMs : 4);
        final raster = Duration(milliseconds: janky ? rasterMs : 3);
        final severity = policy.classify(total, budget);
        return FrameSample(
          frameNumber: i + 1,
          buildDuration: build,
          rasterDuration: raster,
          totalDuration: total,
          vsyncOverhead: Duration.zero,
          timestamp: DateTime.fromMillisecondsSinceEpoch(i * 16),
          severity: severity,
          janky: JankPolicy.isJanky(severity),
          bottleneck: FrameSample.classifyBottleneck(
            build: build,
            raster: raster,
          ),
        );
      }(),
  ];
  final stats = FrameStats.compute(frames);
  return FrameGuardReport(
    schemaVersion: FrameGuardReport.currentSchemaVersion,
    id: 'test-$scenario',
    scenario: scenario,
    startedAt: DateTime.fromMillisecondsSinceEpoch(0),
    endedAt: DateTime.fromMillisecondsSinceEpoch(count * 16),
    frameguardVersion: FrameGuard.packageVersion,
    device: const DeviceMetadata(
      platform: 'android',
      buildMode: FrameGuardBuildMode.profile,
      refreshRateHz: 60,
    ),
    frameBudgetTarget: budget,
    refreshRateHz: 60,
    refreshRateFallback: true,
    frames: frames,
    warmupFrameCount: 0,
    stats: stats,
    markers: const [],
    traces: const [],
    tasks: const [],
    regions: const [],
    customMetrics: const {},
    imageWarnings: const [],
  );
}
