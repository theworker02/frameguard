import 'dart:convert';
import 'dart:io';

import 'package:frameguard/src/diagnostics/explainability.dart';
import 'package:frameguard/src/environment/device_metadata.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/budget_evaluation.dart';
import 'package:frameguard/src/metrics/frame_sample.dart';
import 'package:frameguard/src/metrics/frame_stats.dart';
import 'package:frameguard/src/metrics/image_diagnostics.dart';
import 'package:frameguard/src/metrics/region_stats.dart';
import 'package:frameguard/src/metrics/score.dart';
import 'package:frameguard/src/reporting/comparison.dart';
import 'package:frameguard/src/reporting/html_report.dart';
import 'package:frameguard/src/reporting/json_report.dart';
import 'package:frameguard/src/reporting/markdown_report.dart';
import 'package:frameguard/src/reporting/text_report.dart';
import 'package:frameguard/src/tracing/marker.dart';
import 'package:frameguard/src/tracing/session_options.dart';
import 'package:frameguard/src/tracing/task.dart';
import 'package:frameguard/src/tracing/trace.dart';

/// Structured performance report produced by a completed session.
class FrameGuardReport {
  /// Current on-disk schema version.
  static const int currentSchemaVersion = 1;

  /// Creates a report.
  const FrameGuardReport({
    required this.schemaVersion,
    required this.id,
    required this.scenario,
    required this.startedAt,
    required this.endedAt,
    required this.frameguardVersion,
    required this.device,
    required this.frameBudgetTarget,
    required this.refreshRateHz,
    required this.refreshRateFallback,
    required this.frames,
    required this.warmupFrameCount,
    required this.stats,
    required this.markers,
    required this.traces,
    required this.tasks,
    required this.regions,
    required this.customMetrics,
    required this.imageWarnings,
    this.imageCache,
    this.budget,
    this.budgetEvaluation,
    this.explanation,
    this.debugModeWarning,
    this.sessionOptions,
  });

  /// Schema version for migrations.
  final int schemaVersion;

  /// Session ID.
  final String id;

  /// Scenario name.
  final String scenario;

  /// Start time.
  final DateTime startedAt;

  /// End time.
  final DateTime endedAt;

  /// FrameGuard package version.
  final String frameguardVersion;

  /// Device / environment metadata.
  final DeviceMetadata device;

  /// Target frame interval used for jank classification.
  final Duration frameBudgetTarget;

  /// Effective refresh rate Hz.
  final double refreshRateHz;

  /// Whether refresh rate used the configured fallback.
  final bool refreshRateFallback;

  /// Captured frames (post-warmup).
  final List<FrameSample> frames;

  /// Warmup frames retained for debug (may be truncated).
  final int warmupFrameCount;

  /// Aggregated stats.
  final FrameStats stats;

  /// Custom markers.
  final List<FrameGuardMarker> markers;

  /// Completed traces.
  final List<FrameGuardTraceResult> traces;

  /// Measured tasks.
  final List<TaskMeasurement> tasks;

  /// Region rebuild stats.
  final List<RegionStats> regions;

  /// Custom metrics.
  final Map<String, num> customMetrics;

  /// Image warnings.
  final List<ImageWarning> imageWarnings;

  /// Image cache snapshot when available.
  final ImageCacheSnapshot? imageCache;

  /// Budget used for evaluation, if any.
  final FrameBudget? budget;

  /// Budget evaluation result.
  final BudgetEvaluation? budgetEvaluation;

  /// Explainability output.
  final ScenarioExplanation? explanation;

  /// Debug-mode warning text, if applicable.
  final String? debugModeWarning;

  /// Session options snapshot.
  final FrameGuardSessionOptions? sessionOptions;

  /// Session duration.
  Duration get duration => endedAt.difference(startedAt);

  /// Jank rate convenience.
  double get jankRate => stats.jankRate;

  /// Whether budget evaluation passed (true if no budget).
  bool get passed => budgetEvaluation?.passed ?? true;

  /// Optional decomposable score (secondary to raw metrics).
  FrameGuardScore get score {
    final peak = regions.isEmpty
        ? null
        : regions
            .map((r) => r.peakRebuildsInFrame.toDouble())
            .reduce((a, b) => a > b ? a : b);
    return FrameGuardScore.compute(
      stats,
      peakRebuildsPerFrame: peak,
      targetFrame: frameBudgetTarget,
    );
  }

  /// Evaluates against an explicit [budget].
  BudgetEvaluation evaluate(FrameBudget budget) =>
      BudgetEvaluation.evaluate(stats, budget);

  /// Human-readable summary.
  String summary() => TextReportFormatter(this).summary();

  /// Full terminal report.
  String toText() => TextReportFormatter(this).full();

  /// Compact frame timeline.
  String frameTimeline({int? limit}) =>
      TextReportFormatter(this).frameTimeline(limit: limit);

  /// JSON map (versioned DTO — not raw Dart serialization).
  Map<String, Object?> toJson() => JsonReportEncoder.encode(this);

  /// Pretty JSON string.
  String toJsonString({bool pretty = true}) {
    final map = toJson();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  /// Writes JSON to [file].
  Future<void> writeJson(File file, {bool pretty = true}) async {
    await file.writeAsString(toJsonString(pretty: pretty));
  }

  /// Writes a static HTML report to [file].
  Future<void> writeHtml(File file) async {
    await file.writeAsString(HtmlReportBuilder(this).build());
  }

  /// Writes a Markdown summary (PR comments / job summaries) to [file].
  Future<void> writeMarkdown(File file, {ComparisonResult? comparison}) async {
    await file.writeAsString(
      MarkdownReportBuilder(this, comparison: comparison).build(),
    );
  }

  /// Writes common artifacts (JSON + optional HTML/Markdown) under [directory].
  ///
  /// Filenames default to the scenario slug. Creates [directory] if needed.
  Future<ReportArtifacts> writeArtifacts(
    Directory directory, {
    String? basename,
    bool json = true,
    bool html = false,
    bool markdown = false,
    ComparisonResult? comparison,
  }) async {
    await directory.create(recursive: true);
    final slug = basename ??
        scenario
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_|_$'), '');
    File? jsonFile;
    File? htmlFile;
    File? mdFile;
    if (json) {
      jsonFile = File('${directory.path}/$slug.json');
      await writeJson(jsonFile);
    }
    if (html) {
      htmlFile = File('${directory.path}/$slug.html');
      await writeHtml(htmlFile);
    }
    if (markdown) {
      mdFile = File('${directory.path}/$slug.md');
      await writeMarkdown(mdFile, comparison: comparison);
    }
    return ReportArtifacts(json: jsonFile, html: htmlFile, markdown: mdFile);
  }

  /// Parses a report from JSON DTO.
  factory FrameGuardReport.fromJson(Map<String, Object?> json) =>
      JsonReportEncoder.decode(json);

  /// Loads from a JSON file.
  static Future<FrameGuardReport> load(File file) async {
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      // jsonDecode returns Map<String, dynamic> — cast carefully.
      if (decoded is Map) {
        return FrameGuardReport.fromJson(Map<String, Object?>.from(decoded));
      }
      throw FormatException('Expected a JSON object in ${file.path}');
    }
    return FrameGuardReport.fromJson(decoded);
  }

  /// Copy with overrides.
  FrameGuardReport copyWith({
    int? schemaVersion,
    String? frameguardVersion,
    ScenarioExplanation? explanation,
    BudgetEvaluation? budgetEvaluation,
  }) {
    return FrameGuardReport(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      id: id,
      scenario: scenario,
      startedAt: startedAt,
      endedAt: endedAt,
      frameguardVersion: frameguardVersion ?? this.frameguardVersion,
      device: device,
      frameBudgetTarget: frameBudgetTarget,
      refreshRateHz: refreshRateHz,
      refreshRateFallback: refreshRateFallback,
      frames: frames,
      warmupFrameCount: warmupFrameCount,
      stats: stats,
      markers: markers,
      traces: traces,
      tasks: tasks,
      regions: regions,
      customMetrics: customMetrics,
      imageWarnings: imageWarnings,
      imageCache: imageCache,
      budget: budget,
      budgetEvaluation: budgetEvaluation ?? this.budgetEvaluation,
      explanation: explanation ?? this.explanation,
      debugModeWarning: debugModeWarning,
      sessionOptions: sessionOptions,
    );
  }

  /// Slowest frames for reports.
  List<FrameSample> slowestFrames({int count = 10}) {
    final sorted = [...frames]
      ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
    return sorted.take(count).toList(growable: false);
  }

  /// Whether any frame has severe jank.
  bool get hasSevereJank => stats.jankDistribution.severe > 0;
}

/// Paths produced by [FrameGuardReport.writeArtifacts].
class ReportArtifacts {
  /// Creates an artifacts bundle.
  const ReportArtifacts({this.json, this.html, this.markdown});

  /// JSON report path, if written.
  final File? json;

  /// HTML report path, if written.
  final File? html;

  /// Markdown summary path, if written.
  final File? markdown;
}
