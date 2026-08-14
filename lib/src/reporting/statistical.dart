import 'dart:math' as math;

import 'package:frameguard/src/metrics/percentiles.dart';
import 'package:frameguard/src/reporting/comparison.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Statistical summary across repeated scenario runs.
///
/// Outliers are **flagged**, never deleted. Raw worst frames remain in reports.
class StatisticalSummary {
  /// Creates a summary.
  const StatisticalSummary({
    required this.runCount,
    required this.medianP95Ms,
    required this.medianP99Ms,
    required this.meanP95Ms,
    required this.stdDevP95Ms,
    required this.madP95Ms,
    required this.trimmedMeanP95Ms,
    required this.p95Variance,
    required this.confidenceInterval95P95Ms,
    required this.outlierRunIndexes,
    required this.medianJankRate,
  });

  /// Number of runs included.
  final int runCount;

  /// Median p95 across runs (ms).
  final double medianP95Ms;

  /// Median p99 across runs (ms).
  final double medianP99Ms;

  /// Mean p95 (ms).
  final double meanP95Ms;

  /// Std-dev of p95 (ms).
  final double stdDevP95Ms;

  /// Median absolute deviation of p95 (ms).
  final double madP95Ms;

  /// 10% trimmed mean of p95 (ms).
  final double trimmedMeanP95Ms;

  /// Variance of p95 (ms²).
  final double p95Variance;

  /// Approximate 95% CI half-width for mean p95 (normal approx).
  final double confidenceInterval95P95Ms;

  /// Run indexes flagged as outliers via MAD (not removed).
  final List<int> outlierRunIndexes;

  /// Median jank rate across runs.
  final double medianJankRate;

  /// Builds from reports. Requires ≥1 report.
  factory StatisticalSummary.fromReports(
    List<FrameGuardReport> reports, {
    double madOutlierThreshold = 3.0,
  }) {
    if (reports.isEmpty) {
      throw ArgumentError('StatisticalSummary requires at least one report.');
    }
    final p95 =
        reports.map((r) => r.stats.p95.inMicroseconds / 1000.0).toList();
    final p99 =
        reports.map((r) => r.stats.p99.inMicroseconds / 1000.0).toList();
    final jank = reports.map((r) => r.stats.jankRate).toList();

    final sortedP95 = [...p95]..sort();
    final sortedP99 = [...p99]..sort();
    final sortedJank = [...jank]..sort();

    final mean = sortedP95.reduce((a, b) => a + b) / sortedP95.length;
    var variance = 0.0;
    for (final v in sortedP95) {
      final d = v - mean;
      variance += d * d;
    }
    variance /= sortedP95.length;
    final std = math.sqrt(variance);

    final p95Durations = sortedP95
        .map((ms) => Duration(microseconds: (ms * 1000).round()))
        .toList();
    final mad = Percentiles.mad(p95Durations).inMicroseconds / 1000.0;
    final median = Percentiles.median(p95Durations).inMicroseconds / 1000.0;

    final outliers = <int>[];
    if (mad > 0) {
      for (var i = 0; i < p95.length; i++) {
        final score = (p95[i] - median).abs() / mad;
        if (score >= madOutlierThreshold) outliers.add(i);
      }
    }

    // Normal approx CI: 1.96 * σ / sqrt(n)
    final ci = runCountSafe(sortedP95.length) > 1
        ? 1.96 * std / math.sqrt(sortedP95.length)
        : 0.0;

    return StatisticalSummary(
      runCount: reports.length,
      medianP95Ms: median,
      medianP99Ms: Percentiles.median(
            sortedP99
                .map((ms) => Duration(microseconds: (ms * 1000).round()))
                .toList(),
          ).inMicroseconds /
          1000.0,
      meanP95Ms: mean,
      stdDevP95Ms: std,
      madP95Ms: mad,
      trimmedMeanP95Ms:
          Percentiles.trimmedMean(p95Durations, 0.1).inMicroseconds / 1000.0,
      p95Variance: variance,
      confidenceInterval95P95Ms: ci,
      outlierRunIndexes: outliers,
      medianJankRate: Percentiles.median(
            sortedJank
                .map((j) => Duration(microseconds: (j * 1e6).round()))
                .toList(),
          ).inMicroseconds /
          1e6,
    );
  }

  static int runCountSafe(int n) => n;

  /// Text summary.
  String summary() {
    final buf = StringBuffer()
      ..writeln('STATISTICAL SUMMARY ($runCount runs)')
      ..writeln('Median P95:     ${medianP95Ms.toStringAsFixed(2)} ms')
      ..writeln('Mean P95:       ${meanP95Ms.toStringAsFixed(2)} ms')
      ..writeln('Trimmed mean:   ${trimmedMeanP95Ms.toStringAsFixed(2)} ms')
      ..writeln('P95 std-dev:    ${stdDevP95Ms.toStringAsFixed(2)} ms')
      ..writeln('P95 MAD:        ${madP95Ms.toStringAsFixed(2)} ms')
      ..writeln(
        'Approx 95% CI:  ±${confidenceInterval95P95Ms.toStringAsFixed(2)} ms',
      )
      ..writeln(
        'Median jank:    ${(medianJankRate * 100).toStringAsFixed(2)}%',
      );
    if (outlierRunIndexes.isNotEmpty) {
      buf.writeln(
        'Flagged outliers (kept): runs '
        '${outlierRunIndexes.map((i) => i + 1).join(', ')}',
      );
    }
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'runCount': runCount,
        'medianP95Ms': medianP95Ms,
        'medianP99Ms': medianP99Ms,
        'meanP95Ms': meanP95Ms,
        'stdDevP95Ms': stdDevP95Ms,
        'madP95Ms': madP95Ms,
        'trimmedMeanP95Ms': trimmedMeanP95Ms,
        'p95Variance': p95Variance,
        'confidenceInterval95P95Ms': confidenceInterval95P95Ms,
        'outlierRunIndexes': outlierRunIndexes,
        'medianJankRate': medianJankRate,
      };
}

/// Compares two multi-run statistical summaries for regression.
class StatisticalRegression {
  /// Creates a comparer.
  const StatisticalRegression({
    this.minRuns = 3,
    this.thresholds = const ComparisonThresholds(),
    this.regressionThresholds = const RegressionThresholds(),
  });

  /// Minimum runs required before declaring a regression.
  final int minRuns;

  /// Relative/absolute thresholds.
  final ComparisonThresholds thresholds;

  /// Magnitude thresholds.
  final RegressionThresholds regressionThresholds;

  /// Compares [current] vs [baseline] summaries.
  StatisticalRegressionResult compare({
    required StatisticalSummary baseline,
    required StatisticalSummary current,
    required String scenario,
  }) {
    if (baseline.runCount < minRuns || current.runCount < minRuns) {
      return StatisticalRegressionResult(
        scenario: scenario,
        isRegression: false,
        magnitude: RegressionMagnitude.none,
        insufficientSamples: true,
        message: 'Insufficient runs for statistical regression '
            '(need ≥$minRuns each; '
            'baseline=${baseline.runCount}, current=${current.runCount}).',
        relativeP95Change: 0,
      );
    }

    final base = baseline.medianP95Ms;
    final curr = current.medianP95Ms;
    final rel = base == 0 ? (curr > 0 ? 1.0 : 0.0) : (curr - base) / base;
    final jankDelta = current.medianJankRate - baseline.medianJankRate;
    final regressed =
        rel > thresholds.p95Relative || jankDelta > thresholds.jankRateAbsolute;

    final mag = regressed
        ? _max(
            regressionThresholds.classifyRelative(rel),
            regressionThresholds.classifyJankRateDelta(jankDelta),
          )
        : RegressionMagnitude.none;

    return StatisticalRegressionResult(
      scenario: scenario,
      isRegression: regressed,
      magnitude: mag,
      insufficientSamples: false,
      relativeP95Change: rel,
      message: regressed
          ? 'REGRESSION ($mag): median P95 '
              '${base.toStringAsFixed(1)} → ${curr.toStringAsFixed(1)} ms '
              '(${(rel * 100).toStringAsFixed(1)}%)'
          : 'OK: median P95 '
              '${base.toStringAsFixed(1)} → ${curr.toStringAsFixed(1)} ms',
    );
  }

  RegressionMagnitude _max(RegressionMagnitude a, RegressionMagnitude b) =>
      a.index >= b.index ? a : b;
}

/// Result of [StatisticalRegression.compare].
class StatisticalRegressionResult {
  /// Creates a result.
  const StatisticalRegressionResult({
    required this.scenario,
    required this.isRegression,
    required this.magnitude,
    required this.insufficientSamples,
    required this.message,
    required this.relativeP95Change,
  });

  /// Scenario name.
  final String scenario;

  /// Whether a regression was declared.
  final bool isRegression;

  /// Magnitude classification.
  final RegressionMagnitude magnitude;

  /// True when sample counts were too low to decide.
  final bool insufficientSamples;

  /// Human-readable outcome.
  final String message;

  /// Relative median-p95 change.
  final double relativeP95Change;
}
