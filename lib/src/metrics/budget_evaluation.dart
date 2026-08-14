import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/frame_stats.dart';

/// Result of evaluating a single budget constraint.
class BudgetCheck {
  /// Creates a check result.
  const BudgetCheck({
    required this.name,
    required this.passed,
    required this.actual,
    required this.limit,
    required this.message,
  });

  /// Constraint name (e.g. `jank_rate`, `p95`).
  final String name;

  /// Whether the constraint passed.
  final bool passed;

  /// Human-readable actual value.
  final String actual;

  /// Human-readable limit.
  final String limit;

  /// Full diagnostic line.
  final String message;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'name': name,
        'passed': passed,
        'actual': actual,
        'limit': limit,
        'message': message,
      };
}

/// Aggregate pass/fail evaluation of a [FrameBudget] against [FrameStats].
class BudgetEvaluation {
  /// Creates an evaluation.
  const BudgetEvaluation({
    required this.passed,
    required this.checks,
  });

  /// True only if every defined constraint passed.
  final bool passed;

  /// Individual constraint results.
  final List<BudgetCheck> checks;

  /// Failed checks only.
  Iterable<BudgetCheck> get failures => checks.where((c) => !c.passed);

  /// Evaluates [budget] against [stats].
  factory BudgetEvaluation.evaluate(FrameStats stats, FrameBudget budget) {
    budget.validate();
    final checks = <BudgetCheck>[];

    if (budget.maxJankFrames != null) {
      final ok = stats.jankyFrames <= budget.maxJankFrames!;
      checks.add(
        BudgetCheck(
          name: 'jank_frames',
          passed: ok,
          actual: '${stats.jankyFrames}',
          limit: '<= ${budget.maxJankFrames}',
          message: ok
              ? 'PASS jank frames: ${stats.jankyFrames} <= ${budget.maxJankFrames}'
              : 'FAIL jank frames: ${stats.jankyFrames} > ${budget.maxJankFrames}',
        ),
      );
    }

    if (budget.maxJankRate != null) {
      final ok = stats.jankRate <= budget.maxJankRate!;
      final actualPct = (stats.jankRate * 100).toStringAsFixed(2);
      final limitPct = (budget.maxJankRate! * 100).toStringAsFixed(2);
      checks.add(
        BudgetCheck(
          name: 'jank_rate',
          passed: ok,
          actual: '$actualPct%',
          limit: '<= $limitPct%',
          message: ok
              ? 'PASS jank rate: $actualPct% <= $limitPct%'
              : 'FAIL jank rate: $actualPct% > $limitPct%',
        ),
      );
    }

    void durationCheck(String name, Duration actual, Duration? limit) {
      if (limit == null) return;
      final ok = actual <= limit;
      final a = _fmtMs(actual);
      final l = _fmtMs(limit);
      checks.add(
        BudgetCheck(
          name: name,
          passed: ok,
          actual: a,
          limit: '<= $l',
          message: ok ? 'PASS $name: $a <= $l' : 'FAIL $name: $a > $l',
        ),
      );
    }

    durationCheck('p50', stats.p50, budget.maxP50FrameTime);
    durationCheck('p95', stats.p95, budget.maxP95FrameTime);
    durationCheck('p99', stats.p99, budget.maxP99FrameTime);
    durationCheck('worst', stats.max, budget.maxFrameTime);
    durationCheck('avg_build', stats.averageBuild, budget.maxBuildDuration);
    durationCheck('avg_raster', stats.averageRaster, budget.maxRasterDuration);
    durationCheck('avg_frame', stats.average, budget.maxAverageFrameTime);

    if (budget.maxSevereJankFrames != null) {
      final severe = stats.jankDistribution.severe;
      final ok = severe <= budget.maxSevereJankFrames!;
      checks.add(
        BudgetCheck(
          name: 'severe_jank',
          passed: ok,
          actual: '$severe',
          limit: '<= ${budget.maxSevereJankFrames}',
          message: ok
              ? 'PASS severe jank: $severe <= ${budget.maxSevereJankFrames}'
              : 'FAIL severe jank: $severe > ${budget.maxSevereJankFrames}',
        ),
      );
    }

    return BudgetEvaluation(
      passed: checks.every((c) => c.passed),
      checks: checks,
    );
  }

  /// Text summary for reports.
  String summary() {
    if (checks.isEmpty) return 'No budget constraints defined.';
    final buf = StringBuffer('PERFORMANCE BUDGET\n');
    for (final c in checks) {
      buf.writeln(c.name);
      buf.writeln(c.passed ? 'PASS' : 'FAIL');
      buf.writeln('${c.actual} ${c.limit}');
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'passed': passed,
        'checks': checks.map((c) => c.toJson()).toList(),
      };
}

String _fmtMs(Duration d) =>
    '${(d.inMicroseconds / 1000.0).toStringAsFixed(1)} ms';
