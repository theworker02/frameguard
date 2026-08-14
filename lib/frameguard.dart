/// FrameGuard — automated Flutter performance regression detection.
///
/// Capture frame timings, classify jank, enforce budgets, compare baselines,
/// and fail CI on measurable UI regressions. Completely local: no telemetry,
/// no backend, no accounts.
///
/// ## Quick start
///
/// ```dart
/// void main() {
///   FrameGuard.initialize();
///   runApp(
///     FrameGuardScope(
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ## Sessions
///
/// ```dart
/// final session = FrameGuard.startSession(name: 'home_scroll');
/// // interact...
/// final report = await session.stop();
/// debugPrint(report.summary());
/// ```
///
/// ### Performance tests
///
/// ```dart
/// import 'package:frameguard/frameguard_test.dart';
///
/// final report = await FrameGuardTest.measure(
///   tester,
///   name: 'product_list',
///   action: () async { /* scroll */ },
/// );
/// expect(report, meetsFrameBudget(budget));
/// ```
library frameguard;

export 'src/core/budget_watcher.dart';
export 'src/core/capabilities.dart';
export 'src/core/config.dart';
export 'src/core/config_loader.dart';
export 'src/core/doctor.dart';
export 'src/core/exceptions.dart';
export 'src/core/frameguard.dart';
export 'src/core/platform_adapter.dart';
export 'src/core/project_init.dart';
export 'src/core/sampling_mode.dart';
export 'src/core/stabilization.dart';
export 'src/diagnostics/diagnostic_id.dart';
export 'src/diagnostics/explainability.dart';
export 'src/diagnostics/memory.dart';
export 'src/diagnostics/recommendation.dart';
export 'src/diagnostics/root_cause.dart';
export 'src/diagnostics/suppression.dart';
export 'src/environment/build_mode.dart';
export 'src/environment/device_metadata.dart';
export 'src/metrics/budget.dart';
export 'src/metrics/budget_evaluation.dart';
export 'src/metrics/budget_profile.dart';
export 'src/metrics/budget_suggest.dart';
export 'src/metrics/frame_sample.dart';
export 'src/metrics/frame_stats.dart';
export 'src/metrics/histogram.dart';
export 'src/metrics/image_diagnostics.dart';
export 'src/metrics/jank.dart';
export 'src/metrics/percentiles.dart';
export 'src/metrics/refresh_rate.dart';
export 'src/metrics/region_stats.dart';
export 'src/metrics/score.dart';
export 'src/reporting/aggregate.dart';
export 'src/reporting/baseline.dart';
export 'src/reporting/comparison.dart';
export 'src/reporting/drift.dart';
export 'src/reporting/exporters.dart';
export 'src/reporting/history.dart';
export 'src/reporting/html_report.dart';
export 'src/reporting/json_report.dart';
export 'src/reporting/markdown_report.dart';
export 'src/reporting/report.dart';
export 'src/reporting/statistical.dart';
export 'src/reporting/text_report.dart';
export 'src/tracing/marker.dart';
export 'src/tracing/scenario.dart';
export 'src/tracing/scenario_runner.dart';
export 'src/tracing/session.dart';
export 'src/tracing/task.dart';
export 'src/tracing/trace.dart';
export 'src/widgets/image.dart';
export 'src/widgets/overlay.dart';
export 'src/widgets/region.dart';
export 'src/widgets/scope.dart';
export 'src/widgets/suppress.dart';
