import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';
import 'package:frameguard/frameguard_test.dart';

void main() {
  tearDown(FrameGuard.reset);

  group('BudgetSuggestion', () {
    test('pads percentiles with headroom', () {
      final stats = FrameStats.compute([
        for (var i = 0; i < 20; i++) _frame(12 + (i % 5).toDouble()),
      ]);
      final suggestion = BudgetSuggestion.fromStats(stats, headroom: 0.10);
      expect(suggestion.budget.maxP95FrameTime, isNotNull);
      expect(
        suggestion.budget.maxP95FrameTime!.inMicroseconds,
        greaterThan(stats.p95.inMicroseconds),
      );
      expect(suggestion.toDartSnippet(), contains('FrameBudget'));
      expect(suggestion.toYamlSnippet(), contains('max_p95_ms'));
    });
  });

  group('FrameGuardHistory', () {
    test('append load and drift', () async {
      final dir = await Directory('tmp_check/history_demo').create(
        recursive: true,
      );
      final store = FrameGuardHistory(directory: dir.path);
      await store.clear();

      final a = _sampleReport(totalMs: 12);
      final b = _sampleReport(totalMs: 18);
      await store.appendReport(a);
      await store.appendReport(b);

      final entries = await store.load('sample');
      expect(entries, hasLength(2));
      expect(store.listScenarios(), contains('sample'));

      final drift = await store.p95Drift('sample', gradualThreshold: 0.20);
      expect(drift.points, hasLength(2));
      expect(drift.totalRelativeChange, greaterThan(0.2));
      expect(drift.gradualRegression, isTrue);

      await store.clear(scenario: 'sample');
      expect(await store.load('sample'), isEmpty);
    });
  });

  group('explanation JSON round-trip', () {
    test('preserves primaryFinding through encode/decode', () {
      FrameGuard.initialize(force: true);
      final report = _sampleReport(totalMs: 8);
      final withExpl = report.copyWith(
        explanation: ScenarioExplanation.fromReport(report),
      );
      final json = withExpl.toJson();
      expect(json['explanation'], isA<Map>());
      final restored = FrameGuardReport.fromJson(json);
      expect(restored.explanation, isNotNull);
      expect(
        restored.explanation!.primaryFinding,
        withExpl.explanation!.primaryFinding,
      );
      expect(
        restored.explanation!.primaryFinding,
        contains('Within observed smoothness targets'),
      );
    });
  });

  group('FrameGuardMatchers', () {
    test('jank rate matcher is inclusive', () {
      final report = _sampleReport(totalMs: 8, forceJankRate: 0.01);
      expect(report, hasJankRateBelow(0.01));
      expect(
        FrameGuardMatchers.meetsFrameBudget(
          FrameBudget.forRefreshRate(60, maxJankRate: 1.0),
        ),
        isA<Matcher>(),
      );
    });
  });
}

FrameSample _frame(double totalMs, {bool janky = false}) {
  final total = Duration(microseconds: (totalMs * 1000).round());
  final build = Duration(microseconds: (total.inMicroseconds * 0.6).round());
  final raster = total - build;
  return FrameSample(
    frameNumber: 0,
    buildDuration: build,
    rasterDuration: raster,
    totalDuration: total,
    vsyncOverhead: Duration.zero,
    timestamp: DateTime.utc(2026, 1, 1),
    severity: janky ? JankSeverity.minor : JankSeverity.healthy,
    janky: janky,
    bottleneck: FrameBottleneck.buildBound,
  );
}

FrameGuardReport _sampleReport({
  required double totalMs,
  double? forceJankRate,
}) {
  final frames = [
    for (var i = 0; i < 30; i++)
      _frame(totalMs + (i % 3), janky: forceJankRate != null && i == 0),
  ];
  final stats = FrameStats.compute(frames);
  final adjusted = forceJankRate == null
      ? stats
      : FrameStats(
          totalFrames: stats.totalFrames,
          jankyFrames: (forceJankRate * stats.totalFrames).round(),
          jankRate: forceJankRate,
          average: stats.average,
          median: stats.median,
          p50: stats.p50,
          p90: stats.p90,
          p95: stats.p95,
          p99: stats.p99,
          max: stats.max,
          averageBuild: stats.averageBuild,
          averageRaster: stats.averageRaster,
          buildBoundFrames: stats.buildBoundFrames,
          rasterBoundFrames: stats.rasterBoundFrames,
          mixedFrames: stats.mixedFrames,
          insufficientEvidenceFrames: stats.insufficientEvidenceFrames,
          longestJankStreak: stats.longestJankStreak,
          jankDistribution: stats.jankDistribution,
          histogram: stats.histogram,
          stdDev: stats.stdDev,
        );
  return FrameGuardReport(
    schemaVersion: FrameGuardReport.currentSchemaVersion,
    id: 'sample-id',
    scenario: 'sample',
    startedAt: DateTime.utc(2026, 1, 1),
    endedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
    frameguardVersion: FrameGuard.packageVersion,
    device: const DeviceMetadata(
      platform: 'test',
      buildMode: FrameGuardBuildMode.profile,
      refreshRateHz: 60,
    ),
    frameBudgetTarget: const Duration(milliseconds: 16),
    refreshRateHz: 60,
    refreshRateFallback: false,
    frames: frames,
    warmupFrameCount: 0,
    stats: adjusted,
    markers: const [],
    traces: const [],
    tasks: const [],
    regions: const [],
    customMetrics: const {},
    imageWarnings: const [],
  );
}
