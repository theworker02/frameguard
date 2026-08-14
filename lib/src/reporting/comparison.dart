import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/environment/device_metadata.dart';
import 'package:frameguard/src/reporting/baseline.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Magnitude of a detected regression.
enum RegressionMagnitude {
  /// No regression beyond thresholds.
  none,

  /// Small degradation.
  minor,

  /// Noticeable degradation.
  moderate,

  /// Large degradation.
  severe,
}

/// Configurable thresholds for regression magnitude.
///
/// Documented defaults — not arbitrary silent magic.
class RegressionThresholds {
  /// Creates thresholds.
  ///
  /// [minorPercent] / [moderatePercent] / [severePercent] apply to relative
  /// increases (e.g. p95). Absolute jank-rate deltas use the `*JankRateAbs`
  /// fields.
  const RegressionThresholds({
    this.minorPercent = 0.10,
    this.moderatePercent = 0.25,
    this.severePercent = 0.50,
    this.minorJankRateAbs = 0.005,
    this.moderateJankRateAbs = 0.015,
    this.severeJankRateAbs = 0.03,
  });

  /// Relative increase for minor (≥ this, &lt; moderate).
  final double minorPercent;

  /// Relative increase for moderate.
  final double moderatePercent;

  /// Relative increase for severe.
  final double severePercent;

  /// Absolute jank-rate increase for minor.
  final double minorJankRateAbs;

  /// Absolute jank-rate increase for moderate.
  final double moderateJankRateAbs;

  /// Absolute jank-rate increase for severe.
  final double severeJankRateAbs;

  /// Classifies a relative change (e.g. 0.28 = +28%).
  RegressionMagnitude classifyRelative(double relativeIncrease) {
    if (relativeIncrease < minorPercent) return RegressionMagnitude.none;
    if (relativeIncrease < moderatePercent) return RegressionMagnitude.minor;
    if (relativeIncrease < severePercent) return RegressionMagnitude.moderate;
    return RegressionMagnitude.severe;
  }

  /// Classifies an absolute jank-rate delta.
  RegressionMagnitude classifyJankRateDelta(double delta) {
    if (delta < minorJankRateAbs) return RegressionMagnitude.none;
    if (delta < moderateJankRateAbs) return RegressionMagnitude.minor;
    if (delta < severeJankRateAbs) return RegressionMagnitude.moderate;
    return RegressionMagnitude.severe;
  }
}

/// Thresholds used when deciding if a metric regressed.
class ComparisonThresholds {
  /// Creates comparison thresholds.
  const ComparisonThresholds({
    this.p95Relative = 0.15,
    this.p99Relative = 0.20,
    this.jankRateAbsolute = 0.01,
    this.p95AbsoluteMs,
    this.p99AbsoluteMs,
  });

  /// Relative p95 increase that counts as regression (0.15 = +15%).
  final double p95Relative;

  /// Relative p99 increase.
  final double p99Relative;

  /// Absolute jank-rate increase (e.g. 0.01 = +1 percentage point of rate).
  final double jankRateAbsolute;

  /// Optional absolute p95 increase in ms.
  final double? p95AbsoluteMs;

  /// Optional absolute p99 increase in ms.
  final double? p99AbsoluteMs;
}

/// Result of comparing a current run to a baseline (or another report).
class ComparisonResult {
  /// Creates a comparison result.
  const ComparisonResult({
    required this.scenario,
    required this.isRegression,
    required this.magnitude,
    required this.deltas,
    this.environmentWarning,
    this.passed = true,
  });

  /// Scenario name.
  final String scenario;

  /// Whether thresholds indicate a regression.
  final bool isRegression;

  /// Magnitude classification.
  final RegressionMagnitude magnitude;

  /// Per-metric deltas.
  final List<MetricDelta> deltas;

  /// Environment mismatch warning, if any.
  final String? environmentWarning;

  /// Inverse of [isRegression] for CI friendliness.
  final bool passed;

  /// Text report.
  String summary() {
    final buf = StringBuffer()
      ..writeln('REGRESSION')
      ..writeln('Scenario:')
      ..writeln(scenario);
    if (environmentWarning != null) {
      buf.writeln();
      buf.writeln(environmentWarning);
    }
    for (final d in deltas) {
      buf.writeln();
      buf.writeln('${d.name}:');
      buf.writeln('baseline ${d.baselineLabel}');
      buf.writeln('current  ${d.currentLabel}');
      buf.writeln('change   ${d.changeLabel}');
    }
    buf.writeln();
    buf.writeln('Result:');
    buf.writeln(isRegression ? 'REGRESSION (${magnitude.name})' : 'OK');
    return buf.toString().trimRight();
  }
}

/// A single metric comparison.
class MetricDelta {
  /// Creates a delta.
  const MetricDelta({
    required this.name,
    required this.baselineValue,
    required this.currentValue,
    required this.relativeChange,
    required this.absoluteChange,
    required this.regressed,
    required this.baselineLabel,
    required this.currentLabel,
    required this.changeLabel,
  });

  /// Metric name.
  final String name;

  /// Baseline numeric value.
  final double baselineValue;

  /// Current numeric value.
  final double currentValue;

  /// Relative change (current - baseline) / baseline.
  final double relativeChange;

  /// Absolute change.
  final double absoluteChange;

  /// Whether this metric alone crossed a threshold.
  final bool regressed;

  /// Formatted baseline.
  final String baselineLabel;

  /// Formatted current.
  final String currentLabel;

  /// Formatted change.
  final String changeLabel;
}

/// Compares reports and baselines.
class FrameGuardCompare {
  /// Creates a comparer.
  const FrameGuardCompare({
    this.thresholds = const ComparisonThresholds(),
    this.regressionThresholds = const RegressionThresholds(),
    this.requireMatchingEnvironment = false,
  });

  /// Pass/fail thresholds.
  final ComparisonThresholds thresholds;

  /// Magnitude classification thresholds.
  final RegressionThresholds regressionThresholds;

  /// When true, throw [EnvironmentMismatchException] on env drift.
  final bool requireMatchingEnvironment;

  /// Compares [current] report to [baseline].
  ComparisonResult compareReportToBaseline(
    FrameGuardReport current,
    FrameGuardBaseline baseline,
  ) {
    final warning = _envWarning(baseline.device, current.device);
    if (requireMatchingEnvironment && warning != null) {
      throw EnvironmentMismatchException(warning);
    }

    final deltas = <MetricDelta>[
      _durationLike(
        name: 'P95',
        baseline: baseline.metrics.p95FrameMs,
        current: current.stats.p95.inMicroseconds / 1000.0,
        relativeLimit: thresholds.p95Relative,
        absoluteLimit: thresholds.p95AbsoluteMs,
        unit: 'ms',
      ),
      _durationLike(
        name: 'P99',
        baseline: baseline.metrics.p99FrameMs,
        current: current.stats.p99.inMicroseconds / 1000.0,
        relativeLimit: thresholds.p99Relative,
        absoluteLimit: thresholds.p99AbsoluteMs,
        unit: 'ms',
      ),
      _rateLike(
        name: 'Jank rate',
        baseline: baseline.metrics.jankRate,
        current: current.stats.jankRate,
        absoluteLimit: thresholds.jankRateAbsolute,
      ),
    ];

    final any = deltas.any((d) => d.regressed);
    final worstRel = deltas
        .map((d) => d.relativeChange)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final jankDelta = current.stats.jankRate - baseline.metrics.jankRate;
    final mag = _maxMagnitude([
      regressionThresholds.classifyRelative(worstRel),
      regressionThresholds.classifyJankRateDelta(jankDelta),
    ]);

    return ComparisonResult(
      scenario: current.scenario,
      isRegression: any,
      magnitude: any ? mag : RegressionMagnitude.none,
      deltas: deltas,
      environmentWarning: warning,
      passed: !any,
    );
  }

  /// Compares two reports (A/B experiment style).
  ComparisonResult compareReports(
    FrameGuardReport a,
    FrameGuardReport b, {
    String? labelA,
    String? labelB,
  }) {
    final nameA = labelA ?? a.scenario;
    final nameB = labelB ?? b.scenario;
    final p95A = a.stats.p95.inMicroseconds / 1000.0;
    final p95B = b.stats.p95.inMicroseconds / 1000.0;
    final rel = p95A == 0 ? 0.0 : (p95B - p95A) / p95A;
    final improvement = rel < 0;

    final delta = MetricDelta(
      name: 'P95',
      baselineValue: p95A,
      currentValue: p95B,
      relativeChange: rel,
      absoluteChange: p95B - p95A,
      regressed: rel > thresholds.p95Relative,
      baselineLabel: '${p95A.toStringAsFixed(1)} ms ($nameA)',
      currentLabel: '${p95B.toStringAsFixed(1)} ms ($nameB)',
      changeLabel: improvement
          ? '${((-rel) * 100).toStringAsFixed(1)}% improvement'
          : '${(rel * 100).toStringAsFixed(1)}%',
    );

    return ComparisonResult(
      scenario: '$nameA vs $nameB',
      isRegression: delta.regressed,
      magnitude: delta.regressed
          ? regressionThresholds.classifyRelative(rel)
          : RegressionMagnitude.none,
      deltas: [delta],
      passed: !delta.regressed,
    );
  }

  String? _envWarning(DeviceMetadata baseline, DeviceMetadata current) {
    final issues = <String>[];
    if (baseline.platform != current.platform) {
      issues.add('platform ${baseline.platform} → ${current.platform}');
    }
    if ((baseline.refreshRateHz - current.refreshRateHz).abs() > 1) {
      issues.add(
        'refresh ${baseline.refreshRateHz} Hz → ${current.refreshRateHz} Hz',
      );
    }
    if (baseline.flutterVersion != null &&
        current.flutterVersion != null &&
        baseline.flutterVersion != current.flutterVersion) {
      issues.add(
        'Flutter ${baseline.flutterVersion} → ${current.flutterVersion}',
      );
    }
    if (issues.isEmpty) return null;
    return 'BASELINE COMPARISON WARNING\n'
        'Environments differ: ${issues.join('; ')}\n'
        'Results may not be directly comparable.';
  }

  MetricDelta _durationLike({
    required String name,
    required double baseline,
    required double current,
    required double relativeLimit,
    double? absoluteLimit,
    required String unit,
  }) {
    final abs = current - baseline;
    final rel = baseline == 0 ? (current > 0 ? 1.0 : 0.0) : abs / baseline;
    final regressed =
        rel > relativeLimit || (absoluteLimit != null && abs > absoluteLimit);
    return MetricDelta(
      name: name,
      baselineValue: baseline,
      currentValue: current,
      relativeChange: rel,
      absoluteChange: abs,
      regressed: regressed,
      baselineLabel: '${baseline.toStringAsFixed(1)} $unit',
      currentLabel: '${current.toStringAsFixed(1)} $unit',
      changeLabel: '${rel >= 0 ? '+' : ''}${(rel * 100).toStringAsFixed(1)}%',
    );
  }

  MetricDelta _rateLike({
    required String name,
    required double baseline,
    required double current,
    required double absoluteLimit,
  }) {
    final abs = current - baseline;
    final rel = baseline == 0 ? (current > 0 ? 1.0 : 0.0) : abs / baseline;
    final regressed = abs > absoluteLimit;
    return MetricDelta(
      name: name,
      baselineValue: baseline,
      currentValue: current,
      relativeChange: rel,
      absoluteChange: abs,
      regressed: regressed,
      baselineLabel: '${(baseline * 100).toStringAsFixed(2)}%',
      currentLabel: '${(current * 100).toStringAsFixed(2)}%',
      changeLabel: '${rel >= 0 ? '+' : ''}${(rel * 100).toStringAsFixed(0)}%',
    );
  }

  RegressionMagnitude _maxMagnitude(List<RegressionMagnitude> items) {
    return items.reduce(
      (a, b) => a.index >= b.index ? a : b,
    );
  }
}
