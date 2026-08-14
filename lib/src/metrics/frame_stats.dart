import 'package:frameguard/src/metrics/frame_sample.dart';
import 'package:frameguard/src/metrics/histogram.dart';
import 'package:frameguard/src/metrics/jank.dart';
import 'package:frameguard/src/metrics/percentiles.dart';

/// Aggregated statistics for a set of [FrameSample]s.
///
/// All values are **measured facts** derived from captured timings.
class FrameStats {
  /// Creates frame stats.
  const FrameStats({
    required this.totalFrames,
    required this.jankyFrames,
    required this.jankRate,
    required this.average,
    required this.median,
    required this.p50,
    required this.p90,
    required this.p95,
    required this.p99,
    required this.max,
    required this.averageBuild,
    required this.averageRaster,
    required this.buildBoundFrames,
    required this.rasterBoundFrames,
    required this.mixedFrames,
    required this.insufficientEvidenceFrames,
    required this.longestJankStreak,
    required this.jankDistribution,
    required this.histogram,
    required this.stdDev,
  });

  /// Empty stats (no frames).
  factory FrameStats.empty() => FrameStats(
        totalFrames: 0,
        jankyFrames: 0,
        jankRate: 0,
        average: Duration.zero,
        median: Duration.zero,
        p50: Duration.zero,
        p90: Duration.zero,
        p95: Duration.zero,
        p99: Duration.zero,
        max: Duration.zero,
        averageBuild: Duration.zero,
        averageRaster: Duration.zero,
        buildBoundFrames: 0,
        rasterBoundFrames: 0,
        mixedFrames: 0,
        insufficientEvidenceFrames: 0,
        longestJankStreak: 0,
        jankDistribution: const JankDistribution(),
        histogram: const FrameHistogram(buckets: [], counts: []),
        stdDev: Duration.zero,
      );

  /// Computes stats from [frames].
  factory FrameStats.compute(List<FrameSample> frames) {
    if (frames.isEmpty) return FrameStats.empty();

    final totals = frames.map((f) => f.totalDuration).toList()..sort();
    final builds = frames.map((f) => f.buildDuration).toList();
    final rasters = frames.map((f) => f.rasterDuration).toList();
    final janky = frames.where((f) => f.janky).length;
    final dist = JankDistribution.fromSeverities(frames.map((f) => f.severity));

    var buildBound = 0, rasterBound = 0, mixed = 0, insufficient = 0;
    for (final f in frames) {
      switch (f.bottleneck) {
        case FrameBottleneck.buildBound:
          buildBound++;
        case FrameBottleneck.rasterBound:
          rasterBound++;
        case FrameBottleneck.mixed:
          mixed++;
        case FrameBottleneck.insufficientEvidence:
          insufficient++;
      }
    }

    var streak = 0, longest = 0;
    for (final f in frames) {
      if (f.janky) {
        streak++;
        if (streak > longest) longest = streak;
      } else {
        streak = 0;
      }
    }

    return FrameStats(
      totalFrames: frames.length,
      jankyFrames: janky,
      jankRate: janky / frames.length,
      average: Percentiles.mean(frames.map((f) => f.totalDuration).toList()),
      median: Percentiles.median(totals),
      p50: Percentiles.percentile(totals, 50),
      p90: Percentiles.percentile(totals, 90),
      p95: Percentiles.percentile(totals, 95),
      p99: Percentiles.percentile(totals, 99),
      max: Percentiles.max(frames.map((f) => f.totalDuration).toList()),
      averageBuild: Percentiles.mean(builds),
      averageRaster: Percentiles.mean(rasters),
      buildBoundFrames: buildBound,
      rasterBoundFrames: rasterBound,
      mixedFrames: mixed,
      insufficientEvidenceFrames: insufficient,
      longestJankStreak: longest,
      jankDistribution: dist,
      histogram: FrameHistogram.fromDurations(
        frames.map((f) => f.totalDuration),
      ),
      stdDev: Percentiles.stdDev(
        frames.map((f) => f.totalDuration).toList(),
      ),
    );
  }

  /// Total frames in the sample (post-warmup).
  final int totalFrames;

  /// Count of janky frames.
  final int jankyFrames;

  /// jankyFrames / totalFrames.
  final double jankRate;

  /// Mean total frame time.
  final Duration average;

  /// Median total frame time.
  final Duration median;

  /// p50 total frame time.
  final Duration p50;

  /// p90 total frame time.
  final Duration p90;

  /// p95 total frame time.
  final Duration p95;

  /// p99 total frame time.
  final Duration p99;

  /// Worst total frame time.
  final Duration max;

  /// Mean build duration.
  final Duration averageBuild;

  /// Mean raster duration.
  final Duration averageRaster;

  /// Frames classified likely build-bound.
  final int buildBoundFrames;

  /// Frames classified likely raster-bound.
  final int rasterBoundFrames;

  /// Frames classified mixed.
  final int mixedFrames;

  /// Frames with insufficient evidence.
  final int insufficientEvidenceFrames;

  /// Longest consecutive jank streak.
  final int longestJankStreak;

  /// Severity distribution.
  final JankDistribution jankDistribution;

  /// Frame-time histogram.
  final FrameHistogram histogram;

  /// Standard deviation of total frame time.
  final Duration stdDev;

  /// Text block matching the product spec.
  String summary() {
    String ms(Duration d) =>
        '${(d.inMicroseconds / 1000.0).toStringAsFixed(1)} ms';
    final buf = StringBuffer()
      ..writeln('FRAME SUMMARY')
      ..writeln('Frames:                    $totalFrames')
      ..writeln('Janky frames:              $jankyFrames')
      ..writeln(
        'Jank rate:                 ${(jankRate * 100).toStringAsFixed(1)}%',
      )
      ..writeln('Frame p50:                 ${ms(p50)}')
      ..writeln('Frame p95:                 ${ms(p95)}')
      ..writeln('Frame p99:                 ${ms(p99)}')
      ..writeln('Worst frame:               ${ms(max)}')
      ..writeln('Build-bound frames:        $buildBoundFrames')
      ..writeln('Raster-bound frames:       $rasterBoundFrames')
      ..writeln('Mixed:                     $mixedFrames');
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'totalFrames': totalFrames,
        'jankyFrames': jankyFrames,
        'jankRate': jankRate,
        'averageMs': average.inMicroseconds / 1000.0,
        'medianMs': median.inMicroseconds / 1000.0,
        'p50Ms': p50.inMicroseconds / 1000.0,
        'p90Ms': p90.inMicroseconds / 1000.0,
        'p95Ms': p95.inMicroseconds / 1000.0,
        'p99Ms': p99.inMicroseconds / 1000.0,
        'maxMs': max.inMicroseconds / 1000.0,
        'averageBuildMs': averageBuild.inMicroseconds / 1000.0,
        'averageRasterMs': averageRaster.inMicroseconds / 1000.0,
        'buildBoundFrames': buildBoundFrames,
        'rasterBoundFrames': rasterBoundFrames,
        'mixedFrames': mixedFrames,
        'insufficientEvidenceFrames': insufficientEvidenceFrames,
        'longestJankStreak': longestJankStreak,
        'jankDistribution': jankDistribution.toJson(),
        'histogram': histogram.toJson(),
        'stdDevMs': stdDev.inMicroseconds / 1000.0,
      };
}
