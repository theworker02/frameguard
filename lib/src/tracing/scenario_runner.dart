import 'package:frameguard/src/core/frameguard.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/reporting/aggregate.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:frameguard/src/reporting/statistical.dart';
import 'package:frameguard/src/tracing/scenario.dart';
import 'package:frameguard/src/tracing/session.dart';

/// Runs a [FrameScenario] once or repeatedly for comparable measurements.
///
/// Designed for local experiments and CI orchestration. The [action] callback
/// performs the interaction under test (scroll, navigate, animate, etc.).
class FrameScenarioRunner {
  /// Creates a runner.
  const FrameScenarioRunner({
    required this.scenario,
    this.budget,
    this.runs = 1,
    this.minSampleCount = 1,
  });

  /// Scenario definition (name, warmup, duration hints).
  final FrameScenario scenario;

  /// Optional budget applied to each run.
  final FrameBudget? budget;

  /// How many times to execute [action] (statistical comparison uses ≥3).
  final int runs;

  /// Minimum frames before treating a run as valid for aggregation.
  final int minSampleCount;

  /// Executes [action] for [runs] iterations and returns reports.
  ///
  /// Each run starts a fresh session named `${scenario.name}#n`.
  Future<List<FrameGuardReport>> runAll(
    Future<void> Function(int runIndex) action, {
    FrameGuardSessionOptions? options,
  }) async {
    if (!FrameGuard.isInitialized) {
      FrameGuard.initialize();
    }
    final reports = <FrameGuardReport>[];
    for (var i = 0; i < runs; i++) {
      final report = await runOnce(
        () => action(i),
        runIndex: i,
        options: options,
      );
      reports.add(report);
    }
    return reports;
  }

  /// Executes a single run.
  Future<FrameGuardReport> runOnce(
    Future<void> Function() action, {
    int runIndex = 0,
    FrameGuardSessionOptions? options,
  }) async {
    if (!FrameGuard.isInitialized) {
      FrameGuard.initialize();
    }

    final opts = options ??
        FrameGuardSessionOptions.fromSamplingMode(
          FrameGuard.instance.config.samplingMode,
          warmup: scenario.warmup,
          warmupFrames: scenario.warmupFrames,
          maxFrames: FrameGuard.instance.config.maxFrames,
        );

    final name = runs > 1 ? '${scenario.name}#${runIndex + 1}' : scenario.name;
    final session = FrameGuard.startSession(
      name: name,
      options: opts,
      budget: budget,
      warmup: scenario.warmup,
      warmupFrames: scenario.warmupFrames,
    );

    try {
      await action();
      if (scenario.duration != null) {
        await Future<void>.delayed(scenario.duration!);
      }
    } finally {
      // Always stop even if action throws so timings are flushed.
    }

    final report = await session.stop();
    return report;
  }

  /// Runs repeatedly and returns both reports and aggregate statistics.
  Future<ScenarioRunResult> runAggregated(
    Future<void> Function(int runIndex) action, {
    FrameGuardSessionOptions? options,
  }) async {
    final reports = await runAll(action, options: options);
    final usable =
        reports.where((r) => r.stats.totalFrames >= minSampleCount).toList();
    if (usable.isEmpty) {
      return ScenarioRunResult(
        scenario: scenario,
        reports: reports,
        aggregate: null,
        statistical: null,
      );
    }
    final aggregate = FrameGuardAggregate.fromReports(usable);
    final statistical = StatisticalSummary.fromReports(usable);
    return ScenarioRunResult(
      scenario: scenario,
      reports: reports,
      aggregate: aggregate,
      statistical: statistical,
    );
  }
}

/// Result of a multi-run scenario execution.
class ScenarioRunResult {
  /// Creates a result.
  const ScenarioRunResult({
    required this.scenario,
    required this.reports,
    required this.aggregate,
    required this.statistical,
  });

  /// Scenario definition.
  final FrameScenario scenario;

  /// Per-run reports (including runs below [minSampleCount]).
  final List<FrameGuardReport> reports;

  /// Aggregate across usable runs, if any.
  final FrameGuardAggregate? aggregate;

  /// Statistical summary (median/variance/CI), if any.
  final StatisticalSummary? statistical;

  /// Text summary.
  String summary() {
    final buf = StringBuffer()
      ..writeln('SCENARIO RUNS')
      ..writeln(scenario.name)
      ..writeln('Runs: ${reports.length}');
    if (aggregate != null) {
      buf.writeln();
      buf.writeln(aggregate!.summary());
    }
    if (statistical != null) {
      buf.writeln();
      buf.writeln(statistical!.summary());
    }
    return buf.toString().trimRight();
  }
}
