import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('frameguard_cli_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      await temp.delete(recursive: true);
    }
  });

  test('baseline write/load round-trip', () async {
    FrameGuard.initialize();
    final report = _report();
    final baseline = FrameGuardBaseline.fromReport(report);
    final file = File(p.join(temp.path, 'catalog.json'));
    await baseline.write(file);
    final loaded = await FrameGuardBaseline.load(file);
    expect(loaded.scenario, report.scenario);
    expect(loaded.metrics.p95FrameMs, baseline.metrics.p95FrameMs);
  });

  test('HTML report is self-contained', () {
    FrameGuard.initialize();
    final html = HtmlReportBuilder(_report()).build();
    expect(html, contains('<!DOCTYPE html>'));
    expect(html, contains('FrameGuard'));
    expect(html, contains('catalog_scroll'));
  });

  test('text report includes frame summary', () {
    FrameGuard.initialize();
    final text = _report().toText();
    expect(text, contains('FRAME SUMMARY'));
    expect(text, contains('FRAMEGUARD REPORT'));
  });

  test('check comparison exit semantics via API', () {
    FrameGuard.initialize();
    final baseline = FrameGuardBaseline.fromReport(
      _report(totalMs: 10, jankEvery: 100),
    );
    final current = _report(totalMs: 30, jankEvery: 5);
    final result = const FrameGuardCompare().compareReportToBaseline(
      current,
      baseline,
    );
    expect(result.isRegression, isTrue);
    expect(result.passed, isFalse);
  });

  test('JSON schema version present', () {
    FrameGuard.initialize();
    final map = _report().toJson();
    expect(map['schemaVersion'], 1);
    // Ensure stable DTO keys.
    expect(map.containsKey('stats'), isTrue);
    expect(map.containsKey('device'), isTrue);
    final encoded = jsonEncode(map);
    expect(encoded, isNotEmpty);
  });
}

FrameGuardReport _report({int totalMs = 12, int jankEvery = 20}) {
  const budget = Duration(milliseconds: 16);
  const policy = JankPolicy();
  final frames = <FrameSample>[
    for (var i = 0; i < 40; i++)
      () {
        final janky = i % jankEvery == 0;
        final total = Duration(milliseconds: janky ? totalMs : 8);
        final severity = policy.classify(total, budget);
        return FrameSample(
          frameNumber: i + 1,
          buildDuration: Duration(milliseconds: janky ? 10 : 4),
          rasterDuration: const Duration(milliseconds: 3),
          totalDuration: total,
          vsyncOverhead: Duration.zero,
          timestamp: DateTime.fromMillisecondsSinceEpoch(i * 16),
          severity: severity,
          janky: JankPolicy.isJanky(severity),
          bottleneck: FrameBottleneck.buildBound,
        );
      }(),
  ];
  return FrameGuardReport(
    schemaVersion: 1,
    id: 'cli-test',
    scenario: 'catalog_scroll',
    startedAt: DateTime.now(),
    endedAt: DateTime.now(),
    frameguardVersion: FrameGuard.packageVersion,
    device: const DeviceMetadata(
      platform: 'android',
      buildMode: FrameGuardBuildMode.profile,
      refreshRateHz: 120,
    ),
    frameBudgetTarget: budget,
    refreshRateHz: 120,
    refreshRateFallback: false,
    frames: frames,
    warmupFrameCount: 0,
    stats: FrameStats.compute(frames),
    markers: const [],
    traces: const [],
    tasks: const [],
    regions: const [],
    customMetrics: const {},
    imageWarnings: const [],
  );
}
