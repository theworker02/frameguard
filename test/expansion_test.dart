import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';

void main() {
  group('FrameGuardConfigLoader', () {
    test('parses example-shaped YAML', () {
      const yaml = '''
frameguard:
  refresh_rate: 120
  sampling_mode: full
  budgets:
    max_jank_rate: 0.01
    max_p95_ms: 8.5
    max_p99_ms: 12
  profiles:
    mid_range:
      max_jank_rate: 0.02
      max_p95_ms: 18
''';
      final config = FrameGuardConfigLoader.fromYaml(yaml);
      expect(config.samplingMode, SamplingMode.full);
      expect(config.defaultBudget?.maxJankRate, 0.01);
      expect(
        config.defaultBudget?.maxP95FrameTime?.inMicroseconds,
        closeTo(8500, 5),
      );
      expect(config.profiles.containsKey('mid_range'), isTrue);
      expect(config.profiles['mid_range']!.budget.maxJankRate, 0.02);
    });

    test('rejects missing frameguard root', () {
      expect(
        () => FrameGuardConfigLoader.fromYaml('other:\n  x: 1\n'),
        throwsA(isA<FrameGuardException>()),
      );
    });
  });

  group('StatisticalSummary', () {
    test('computes median and flags outliers', () {
      FrameGuard.initialize();
      final reports = [
        _report(p95Ms: 10),
        _report(p95Ms: 11),
        _report(p95Ms: 10.5),
        _report(p95Ms: 40), // outlier
        _report(p95Ms: 10.2),
      ];
      final summary = StatisticalSummary.fromReports(reports);
      expect(summary.runCount, 5);
      expect(summary.medianP95Ms, closeTo(10.5, 1.0));
      expect(summary.outlierRunIndexes, isNotEmpty);
      expect(summary.summary(), contains('STATISTICAL SUMMARY'));
    });

    test('statistical regression requires min runs', () {
      final a = StatisticalSummary.fromReports([
        _report(p95Ms: 10),
        _report(p95Ms: 10),
      ]);
      final b = StatisticalSummary.fromReports([
        _report(p95Ms: 14),
        _report(p95Ms: 15),
      ]);
      final result = const StatisticalRegression(minRuns: 3).compare(
        baseline: a,
        current: b,
        scenario: 's',
      );
      expect(result.insufficientSamples, isTrue);
      expect(result.isRegression, isFalse);
    });

    test('detects regression with enough runs', () {
      final baseline = StatisticalSummary.fromReports([
        for (var i = 0; i < 5; i++) _report(p95Ms: 10),
      ]);
      final current = StatisticalSummary.fromReports([
        for (var i = 0; i < 5; i++) _report(p95Ms: 14),
      ]);
      final result = const StatisticalRegression(minRuns: 3).compare(
        baseline: baseline,
        current: current,
        scenario: 'catalog',
      );
      expect(result.isRegression, isTrue);
      expect(result.magnitude, isNot(RegressionMagnitude.none));
    });
  });

  group('ReportExporter', () {
    test('csv and junit and sarif', () {
      FrameGuard.initialize();
      final report = _report(p95Ms: 20, janky: true);
      final exporter = ReportExporter(report);
      final csv = exporter.toCsv();
      expect(csv, contains('p95_ms'));
      expect(csv, contains('frame,total_ms'));

      final junit = exporter.toJUnit();
      expect(junit, contains('<testsuite'));
      expect(junit, contains('frameguard.performance'));

      final sarif = exporter.toSarif();
      expect(sarif, contains('"version": "2.1.0"'));
      expect(sarif, contains('FrameGuard'));
    });
  });

  group('MemoryPressureTracker', () {
    test('reports Unavailable by default', () {
      final tracker = MemoryPressureTracker();
      tracker.begin();
      tracker.end();
      final summary = tracker.summarize(during: 'scroll');
      expect(summary.available, isFalse);
      expect(summary.summary(), contains('Unavailable'));
    });

    test('reports growth when probe provides data', () {
      final tracker = MemoryPressureTracker(probe: _FakeMemoryProbe());
      tracker.begin();
      tracker.end();
      final summary = tracker.summarize(during: 'catalog_scroll');
      expect(summary.available, isTrue);
      expect(summary.growthBytes, 5 * 1024 * 1024);
      expect(summary.summary(), contains('MEMORY PRESSURE'));
    });
  });

  group('PlatformAdapters', () {
    tearDown(PlatformAdapters.reset);

    test('default native metrics are Unavailable not zeros', () {
      final metrics = PlatformAdapters.active.nativeMetrics();
      expect(metrics.values, isNot(contains(0)));
      expect(metrics.values.join(' '), contains('Unavailable'));
    });

    test('can register android adapter', () {
      PlatformAdapters.register(const AndroidPlatformAdapter());
      expect(PlatformAdapters.active.name, 'android');
      expect(
        PlatformAdapters.active.nativeMetrics()['androidJankStats'],
        'Unavailable',
      );
    });
  });
}

class _FakeMemoryProbe implements MemoryProbe {
  var _n = 0;

  @override
  MemoryProbeResult sample() {
    _n++;
    return MemoryProbeResult(
      available: true,
      heapUsageBytes: _n == 1 ? 10 * 1024 * 1024 : 15 * 1024 * 1024,
    );
  }
}

FrameGuardReport _report({required double p95Ms, bool janky = false}) {
  const budget = Duration(milliseconds: 16);
  final total = Duration(microseconds: (p95Ms * 1000).round());
  final severity = janky ? JankSeverity.major : JankSeverity.healthy;
  final frames = [
    for (var i = 0; i < 30; i++)
      FrameSample(
        frameNumber: i + 1,
        buildDuration: const Duration(milliseconds: 4),
        rasterDuration: const Duration(milliseconds: 3),
        totalDuration: i == 15 ? total : const Duration(milliseconds: 8),
        vsyncOverhead: Duration.zero,
        timestamp: DateTime.fromMillisecondsSinceEpoch(i * 16),
        severity: i == 15 ? severity : JankSeverity.healthy,
        janky: i == 15 && janky,
        bottleneck: FrameBottleneck.buildBound,
      ),
  ];
  // Force p95 near requested by filling with that duration.
  final forced = [
    for (var i = 0; i < 40; i++)
      FrameSample(
        frameNumber: i + 1,
        buildDuration: Duration(milliseconds: (p95Ms * 0.7).round()),
        rasterDuration: Duration(milliseconds: (p95Ms * 0.3).round()),
        totalDuration: total,
        vsyncOverhead: Duration.zero,
        timestamp: DateTime.fromMillisecondsSinceEpoch(i * 16),
        severity: severity,
        janky: janky,
        bottleneck: FrameBottleneck.buildBound,
      ),
  ];
  final stats = FrameStats.compute(forced);
  return FrameGuardReport(
    schemaVersion: 1,
    id: 'stat-$p95Ms',
    scenario: 's',
    startedAt: DateTime.now(),
    endedAt: DateTime.now(),
    frameguardVersion: FrameGuard.packageVersion,
    device: const DeviceMetadata(
      platform: 'test',
      buildMode: FrameGuardBuildMode.profile,
      refreshRateHz: 60,
    ),
    frameBudgetTarget: budget,
    refreshRateHz: 60,
    refreshRateFallback: true,
    frames: forced.isEmpty ? frames : forced,
    warmupFrameCount: 0,
    stats: stats,
    markers: const [],
    traces: const [],
    tasks: const [],
    regions: const [],
    customMetrics: const {},
    imageWarnings: const [],
    budget: FrameBudget(maxP95FrameTime: budget),
    budgetEvaluation: BudgetEvaluation.evaluate(
      stats,
      FrameBudget(maxP95FrameTime: budget),
    ),
  );
}
