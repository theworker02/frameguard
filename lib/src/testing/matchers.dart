import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/budget_evaluation.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Matcher: report meets [budget].
Matcher meetsFrameBudget(FrameBudget budget) => _MeetsBudget(budget);

/// Alias matching the product-spec name.
Matcher meetsBudget(FrameBudget budget) => meetsFrameBudget(budget);

/// Matcher: no severe jank frames.
const Matcher hasNoSevereJank = _HasNoSevereJank();

/// Matcher: p95 below [max].
Matcher hasP95Below(Duration max) => _HasP95Below(max);

/// Matcher: p99 below [max].
Matcher hasP99Below(Duration max) => _HasP99Below(max);

/// Matcher: jank rate below [maxRate] (0–1).
Matcher hasJankRateBelow(double maxRate) => _HasJankRateBelow(maxRate);

/// Namespace for discoverability (`FrameGuardMatchers.meetsBudget(...)`).
abstract final class FrameGuardMatchers {
  /// See top-level [meetsFrameBudget].
  static Matcher meetsFrameBudget(FrameBudget budget) =>
      _MeetsBudget(budget);

  /// Alias for [meetsFrameBudget].
  static Matcher meetsBudget(FrameBudget budget) => _MeetsBudget(budget);

  /// See [hasNoSevereJank].
  static const Matcher noSevereJank = hasNoSevereJank;

  /// See [hasP95Below].
  static Matcher p95Below(Duration max) => hasP95Below(max);

  /// See [hasP99Below].
  static Matcher p99Below(Duration max) => hasP99Below(max);

  /// See [hasJankRateBelow].
  static Matcher jankRateBelow(double maxRate) => hasJankRateBelow(maxRate);
}

class _MeetsBudget extends Matcher {
  const _MeetsBudget(this.budget);
  final FrameBudget budget;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! FrameGuardReport) return false;
    final eval = BudgetEvaluation.evaluate(item.stats, budget);
    matchState['evaluation'] = eval;
    return eval.passed;
  }

  @override
  Description describe(Description description) =>
      description.add('meets FrameBudget');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final eval = matchState['evaluation'] as BudgetEvaluation?;
    if (eval == null) {
      return mismatchDescription.add('was not a FrameGuardReport');
    }
    mismatchDescription.add('budget failed:\n');
    for (final f in eval.failures) {
      mismatchDescription.add('  ${f.message}\n');
    }
    if (item is FrameGuardReport) {
      mismatchDescription.add(item.summary());
    }
    return mismatchDescription;
  }
}

class _HasNoSevereJank extends Matcher {
  const _HasNoSevereJank();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! FrameGuardReport) return false;
    matchState['severe'] = item.stats.jankDistribution.severe;
    return item.stats.jankDistribution.severe == 0;
  }

  @override
  Description describe(Description description) =>
      description.add('has no severe jank frames');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final severe = matchState['severe'];
    return mismatchDescription.add('had $severe severe jank frame(s)');
  }
}

class _HasP95Below extends Matcher {
  const _HasP95Below(this.max);
  final Duration max;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! FrameGuardReport) return false;
    matchState['p95'] = item.stats.p95;
    return item.stats.p95 <= max;
  }

  @override
  Description describe(Description description) => description.add(
        'has p95 <= ${(max.inMicroseconds / 1000).toStringAsFixed(1)} ms',
      );

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final p95 = matchState['p95'] as Duration?;
    return mismatchDescription.add(
      'p95 was ${(p95?.inMicroseconds ?? 0) / 1000.0} ms',
    );
  }
}

class _HasP99Below extends Matcher {
  const _HasP99Below(this.max);
  final Duration max;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! FrameGuardReport) return false;
    matchState['p99'] = item.stats.p99;
    return item.stats.p99 <= max;
  }

  @override
  Description describe(Description description) => description.add(
        'has p99 <= ${(max.inMicroseconds / 1000).toStringAsFixed(1)} ms',
      );

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final p99 = matchState['p99'] as Duration?;
    return mismatchDescription.add(
      'p99 was ${(p99?.inMicroseconds ?? 0) / 1000.0} ms',
    );
  }
}

class _HasJankRateBelow extends Matcher {
  const _HasJankRateBelow(this.maxRate);
  final double maxRate;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! FrameGuardReport) return false;
    matchState['rate'] = item.jankRate;
    return item.jankRate <= maxRate;
  }

  @override
  Description describe(Description description) =>
      description.add('has jank rate <= $maxRate');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final rate = matchState['rate'] as double?;
    return mismatchDescription.add('jank rate was $rate');
  }
}
