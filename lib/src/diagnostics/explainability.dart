import 'package:frameguard/src/diagnostics/diagnostic_id.dart';
import 'package:frameguard/src/diagnostics/recommendation.dart';
import 'package:frameguard/src/diagnostics/root_cause.dart';
import 'package:frameguard/src/diagnostics/suppression.dart';
import 'package:frameguard/src/metrics/frame_sample.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Evidence-backed explanation of why a scenario failed or was flagged.
///
/// Distinguishes measured facts from derived classifications and heuristic
/// suggestions — never mixes the categories.
class ScenarioExplanation {
  /// Creates an explanation.
  const ScenarioExplanation({
    required this.primaryFinding,
    required this.evidence,
    required this.contributors,
    required this.recommendations,
    this.diagnostics = const [],
  });

  /// Short primary finding (derived classification).
  final String primaryFinding;

  /// Bullet evidence strings grounded in measurements.
  final List<String> evidence;

  /// Ranked likely contributors.
  final List<RootCauseContributor> contributors;

  /// Conservative recommendations tied to observations.
  final List<Recommendation> recommendations;

  /// Fired diagnostic IDs.
  final List<FrameDiagnostic> diagnostics;

  /// Builds an explanation from a completed report.
  factory ScenarioExplanation.fromReport(FrameGuardReport report) {
    final stats = report.stats;
    final evidence = <String>[];
    final contributors = <RootCauseContributor>[];
    final recommendations = <Recommendation>[];
    final diagnostics = <FrameDiagnostic>[];

    final janky = report.frames.where((f) => f.janky).toList();
    // Classify bottlenecks from janky frames first — healthy frames often look
    // mildly build-bound without indicating a regression.
    final ranked = (janky.isNotEmpty ? janky : report.frames).toList()
      ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
    final top = ranked.take(10).toList();

    final buildHeavy =
        top.where((f) => f.bottleneck == FrameBottleneck.buildBound).length;
    final rasterHeavy =
        top.where((f) => f.bottleneck == FrameBottleneck.rasterBound).length;

    String primary;
    if (stats.totalFrames == 0) {
      primary = 'No frames captured';
    } else if (janky.isEmpty && (report.passed)) {
      primary = 'Within observed smoothness targets';
      evidence.add('No janky frames in ${stats.totalFrames} samples');
    } else if (buildHeavy >= rasterHeavy &&
        buildHeavy >= 3 &&
        janky.isNotEmpty) {
      primary = 'Excessive build work';
      diagnostics.add(FrameDiagnostic.buildFrameOverBudget);
      evidence.add(
        '$buildHeavy of ${top.length} worst janky frames were build-bound',
      );
      contributors.add(
        const RootCauseContributor(
          title: 'Excessive build work',
          confidence: DiagnosticConfidence.high,
          category: ContributorCategory.build,
        ),
      );
      recommendations.add(Recommendation.buildBound());
    } else if (rasterHeavy > buildHeavy &&
        rasterHeavy >= 3 &&
        janky.isNotEmpty) {
      primary = 'Raster/GPU-side work';
      diagnostics.add(FrameDiagnostic.rasterFrameOverBudget);
      evidence.add(
        '$rasterHeavy of ${top.length} worst janky frames were raster-bound',
      );
      contributors.add(
        const RootCauseContributor(
          title: 'Raster-bound frame spikes',
          confidence: DiagnosticConfidence.high,
          category: ContributorCategory.raster,
        ),
      );
      recommendations.add(Recommendation.rasterBound());

      // Heuristic hitch pattern: first-spike raster with healthy build.
      if (_possibleRasterHitch(janky)) {
        diagnostics.add(FrameDiagnostic.possibleRasterHitch);
        evidence.add(
          'Raster spiked while build stayed low — possible hitch pattern '
          '(shader compilation, clipping, saveLayer, or large image rasterization). '
          'This is a heuristic, not direct shader detection.',
        );
        contributors.add(
          const RootCauseContributor(
            title: 'Possible raster hitch',
            confidence: DiagnosticConfidence.medium,
            category: ContributorCategory.raster,
          ),
        );
      }
    } else if (stats.jankyFrames > 0) {
      primary = 'Mixed or unclassified frame spikes';
      evidence.add(
        '${stats.jankyFrames} janky frames '
        '(${(stats.jankRate * 100).toStringAsFixed(1)}%)',
      );
    } else {
      primary = 'Within observed smoothness targets';
      evidence.add('No janky frames in ${stats.totalFrames} samples');
    }

    // Region rebuild evidence.
    for (final region in report.regions) {
      if (region.rebuilds >= 20 || region.peakRebuildsInFrame >= 5) {
        diagnostics.add(FrameDiagnostic.excessiveRebuilds);
        evidence.add(
          '${region.name} rebuilt ${region.rebuilds} times '
          '(peak ${region.peakRebuildsInFrame}/frame)',
        );
        contributors.add(
          RootCauseContributor(
            title: '${region.name} rebuild burst',
            confidence: region.peakRebuildsInFrame >= 8
                ? DiagnosticConfidence.high
                : DiagnosticConfidence.medium,
            category: ContributorCategory.rebuilds,
          ),
        );
        recommendations.add(Recommendation.excessiveRebuilds(region.name));
      }
    }

    // Sync tasks.
    for (final task in report.tasks) {
      if (task.exceededBudget) {
        diagnostics.add(FrameDiagnostic.longSyncTask);
        evidence.add(
          'Task ${task.name} took '
          '${(task.duration.inMicroseconds / 1000).toStringAsFixed(1)} ms '
          'and overlapped ${task.overlappingSlowFrames} slow frames',
        );
        contributors.add(
          RootCauseContributor(
            title: 'Synchronous work: ${task.name}',
            confidence: DiagnosticConfidence.high,
            category: ContributorCategory.syncWork,
          ),
        );
        recommendations.add(Recommendation.longSyncTask());
      }
    }

    // Image warnings.
    for (final img in report.imageWarnings) {
      diagnostics.add(FrameDiagnostic.oversizedImage);
      evidence.add(img.summaryLine);
      contributors.add(
        RootCauseContributor(
          title: 'Oversized image: ${img.description}',
          confidence: DiagnosticConfidence.medium,
          category: ContributorCategory.images,
        ),
      );
      recommendations.add(Recommendation.oversizedImage());
    }

    if (stats.averageRaster.inMilliseconds < 7 && buildHeavy >= 3) {
      evidence
          .add('Raster timings remained relatively healthy during slow frames');
    }

    // Deduplicate diagnostics while preserving order; honor suppressions.
    final seen = <FrameDiagnostic>{};
    final uniqueDiagnostics = diagnostics
        .where((d) => !DiagnosticSuppression.isSuppressed(d))
        .where((d) => seen.add(d))
        .toList(growable: false);

    contributors.sort(
      (a, b) => b.confidence.index.compareTo(a.confidence.index),
    );

    return ScenarioExplanation(
      primaryFinding: primary,
      evidence: evidence,
      contributors: contributors,
      recommendations: recommendations,
      diagnostics: uniqueDiagnostics,
    );
  }

  static bool _possibleRasterHitch(List<FrameSample> janky) {
    if (janky.length < 2) return false;
    final rasterSpikes = janky.where(
      (f) =>
          f.bottleneck == FrameBottleneck.rasterBound &&
          f.buildDuration.inMilliseconds < 8 &&
          f.rasterDuration.inMilliseconds >= 20,
    );
    return rasterSpikes.length == 1 ||
        (rasterSpikes.isNotEmpty && janky.length <= 5);
  }

  /// Text block for reports.
  String summary() {
    final buf = StringBuffer()
      ..writeln('WHY THIS SCENARIO FAILED')
      ..writeln('Primary finding:')
      ..writeln(primaryFinding)
      ..writeln('Evidence:');
    for (final e in evidence) {
      buf.writeln('- $e');
    }
    if (contributors.isNotEmpty) {
      buf.writeln();
      buf.writeln(RootCauseContributor.formatList(contributors));
    }
    if (recommendations.isNotEmpty) {
      buf.writeln();
      buf.writeln('Potential improvements:');
      for (final r in recommendations) {
        for (final tip in r.suggestions) {
          buf.writeln('- $tip');
        }
      }
    }
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'primaryFinding': primaryFinding,
        'evidence': evidence,
        'contributors': contributors.map((c) => c.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'diagnostics': diagnostics.map((d) => d.id).toList(),
      };

  /// Restores from JSON DTO (best-effort for unknown enums).
  factory ScenarioExplanation.fromJson(Map<String, Object?> json) {
    final diagIds = (json['diagnostics'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final diagnostics = <FrameDiagnostic>[
      for (final id in diagIds)
        ...FrameDiagnostic.values.where((d) => d.id == id).take(1),
    ];
    final contributors = (json['contributors'] as List? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => RootCauseContributor.fromJson(Map<String, Object?>.from(e)))
        .toList();
    final recommendations = (json['recommendations'] as List? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Recommendation.fromJson(Map<String, Object?>.from(e)))
        .toList();
    return ScenarioExplanation(
      primaryFinding: json['primaryFinding'] as String? ?? '',
      evidence: (json['evidence'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      contributors: contributors,
      recommendations: recommendations,
      diagnostics: diagnostics,
    );
  }
}
