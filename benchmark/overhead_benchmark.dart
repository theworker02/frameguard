import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';

/// Micro-benchmarks for FrameGuard overhead (run with `flutter test benchmark`).
void main() {
  tearDown(FrameGuard.reset);

  test('frame sample classification throughput', () {
    final sw = Stopwatch()..start();
    var buildBound = 0;
    for (var i = 0; i < 100000; i++) {
      final b = FrameSample.classifyBottleneck(
        build: Duration(milliseconds: 5 + (i % 20)),
        raster: Duration(milliseconds: 3 + (i % 10)),
      );
      if (b == FrameBottleneck.buildBound) buildBound++;
    }
    sw.stop();
    // Sanity: should complete quickly on CI hardware.
    expect(sw.elapsedMilliseconds, lessThan(2000));
    expect(buildBound, greaterThan(0));
  });

  test('stats compute on 10k frames', () {
    final frames = [
      for (var i = 0; i < 10000; i++)
        FrameSample(
          frameNumber: i,
          buildDuration: const Duration(milliseconds: 5),
          rasterDuration: const Duration(milliseconds: 3),
          totalDuration: Duration(milliseconds: 8 + (i % 5)),
          vsyncOverhead: Duration.zero,
          timestamp: DateTime.fromMillisecondsSinceEpoch(i),
          severity: JankSeverity.healthy,
          janky: false,
          bottleneck: FrameBottleneck.insufficientEvidence,
        ),
    ];
    final sw = Stopwatch()..start();
    final stats = FrameStats.compute(frames);
    sw.stop();
    expect(stats.totalFrames, 10000);
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });

  test('JSON encode 2k frames', () {
    FrameGuard.initialize();
    final frames = [
      for (var i = 0; i < 2000; i++)
        FrameSample(
          frameNumber: i,
          buildDuration: const Duration(milliseconds: 4),
          rasterDuration: const Duration(milliseconds: 3),
          totalDuration: const Duration(milliseconds: 8),
          vsyncOverhead: Duration.zero,
          timestamp: DateTime.fromMillisecondsSinceEpoch(i),
          severity: JankSeverity.healthy,
          janky: false,
          bottleneck: FrameBottleneck.buildBound,
        ),
    ];
    final report = FrameGuardReport(
      schemaVersion: 1,
      id: 'bench',
      scenario: 'bench',
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      frameguardVersion: FrameGuard.packageVersion,
      device: const DeviceMetadata(
        platform: 'test',
        buildMode: FrameGuardBuildMode.profile,
        refreshRateHz: 60,
      ),
      frameBudgetTarget: const Duration(milliseconds: 16),
      refreshRateHz: 60,
      refreshRateFallback: true,
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
    final sw = Stopwatch()..start();
    final json = report.toJsonString(pretty: false);
    sw.stop();
    expect(json.length, greaterThan(1000));
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
