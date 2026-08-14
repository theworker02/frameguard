import 'dart:math' as math;

import 'package:frameguard/src/metrics/percentiles.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Aggregates multiple scenario runs for statistical comparison.
class FrameGuardAggregate {
  /// Creates an aggregate.
  const FrameGuardAggregate({
    required this.reports,
    required this.medianP95,
    required this.medianP99,
    required this.medianJankRate,
    required this.totalJankFrames,
    required this.p95Variance,
    required this.p95StdDev,
    required this.bestRun,
    required this.worstRun,
    required this.consistencyScore,
  });

  /// Source reports.
  final List<FrameGuardReport> reports;

  /// Median p95 across runs.
  final Duration medianP95;

  /// Median p99 across runs.
  final Duration medianP99;

  /// Median jank rate across runs.
  final double medianJankRate;

  /// Sum of janky frames across runs.
  final int totalJankFrames;

  /// Variance of p95 (ms²).
  final double p95Variance;

  /// Std-dev of p95.
  final Duration p95StdDev;

  /// Best (lowest p95) run.
  final FrameGuardReport bestRun;

  /// Worst (highest p95) run.
  final FrameGuardReport worstRun;

  /// 0–100 consistency score (higher = more stable). Heuristic.
  final double consistencyScore;

  /// Builds from a list of reports. Requires at least one.
  factory FrameGuardAggregate.fromReports(List<FrameGuardReport> reports) {
    if (reports.isEmpty) {
      throw ArgumentError('FrameGuardAggregate requires at least one report.');
    }
    final p95s = reports.map((r) => r.stats.p95).toList()..sort();
    final p99s = reports.map((r) => r.stats.p99).toList()..sort();
    final janks = reports.map((r) => r.stats.jankRate).toList()..sort();
    final p95Ms = p95s.map((d) => d.inMicroseconds / 1000.0).toList();

    final mean = p95Ms.reduce((a, b) => a + b) / p95Ms.length;
    var variance = 0.0;
    for (final v in p95Ms) {
      final d = v - mean;
      variance += d * d;
    }
    variance /= p95Ms.length;
    final std = math.sqrt(variance);

    final sortedByP95 = [...reports]
      ..sort((a, b) => a.stats.p95.compareTo(b.stats.p95));

    // Consistency: lower CV → higher score.
    final cv = mean == 0 ? 0.0 : std / mean;
    final consistency = (100 * (1 - cv.clamp(0, 1))).clamp(0, 100);

    final jankSorted = janks.map((j) {
      return Duration(microseconds: (j * 1e6).round());
    }).toList();

    return FrameGuardAggregate(
      reports: reports,
      medianP95: Percentiles.median(p95s),
      medianP99: Percentiles.median(p99s),
      medianJankRate: Percentiles.median(jankSorted).inMicroseconds / 1e6,
      totalJankFrames: reports.fold<int>(0, (a, r) => a + r.stats.jankyFrames),
      p95Variance: variance,
      p95StdDev: Duration(microseconds: (std * 1000).round()),
      bestRun: sortedByP95.first,
      worstRun: sortedByP95.last,
      consistencyScore: consistency.toDouble(),
    );
  }

  /// Text summary.
  String summary() {
    String ms(Duration d) =>
        '${(d.inMicroseconds / 1000.0).toStringAsFixed(1)} ms';
    final buf = StringBuffer()
      ..writeln('AGGREGATE (${reports.length} runs)')
      ..writeln('Median P95:     ${ms(medianP95)}')
      ..writeln('Median P99:     ${ms(medianP99)}')
      ..writeln(
        'Median jank:    ${(medianJankRate * 100).toStringAsFixed(2)}%',
      )
      ..writeln('Total jank:     $totalJankFrames frames')
      ..writeln('P95 std-dev:    ${ms(p95StdDev)}')
      ..writeln('Best run:       ${bestRun.id} (${ms(bestRun.stats.p95)})')
      ..writeln('Worst run:      ${worstRun.id} (${ms(worstRun.stats.p95)})')
      ..writeln(
        'Consistency:    ${consistencyScore.toStringAsFixed(0)} / 100',
      );
    return buf.toString().trimRight();
  }
}
