import 'package:frameguard/src/diagnostics/diagnostic_id.dart';

/// Conservative, observation-tied improvement suggestions.
///
/// Phrased as possibilities — never guaranteed fixes.
class Recommendation {
  /// Creates a recommendation.
  const Recommendation({
    required this.diagnostic,
    required this.suggestions,
  });

  /// Related diagnostic ID.
  final FrameDiagnostic diagnostic;

  /// Suggested investigations / changes.
  final List<String> suggestions;

  /// Rebuild-heavy guidance.
  factory Recommendation.excessiveRebuilds(String region) => Recommendation(
        diagnostic: FrameDiagnostic.excessiveRebuilds,
        suggestions: [
          'isolate rapidly changing state away from region "$region"',
          'reduce rebuild scope (selectors, listenables, InheritedWidget)',
          'use const widgets where appropriate',
          'inspect listeners that invalidate this region',
        ],
      );

  /// Build-bound guidance.
  factory Recommendation.buildBound() => const Recommendation(
        diagnostic: FrameDiagnostic.buildFrameOverBudget,
        suggestions: [
          'profile build methods of widgets dirty during the slow frames',
          'defer non-critical work off the build path',
          'split large widget subtrees',
          'cache expensive derived values outside build',
        ],
      );

  /// Raster-bound guidance.
  factory Recommendation.rasterBound() => const Recommendation(
        diagnostic: FrameDiagnostic.rasterFrameOverBudget,
        suggestions: [
          'inspect clipping and saveLayer usage',
          'reduce overdraw and complex shadows',
          'simplify opacity / backdrop filters during animation',
          'inspect oversized images contributing to raster cost',
        ],
      );

  /// Sync task guidance.
  factory Recommendation.longSyncTask() => const Recommendation(
        diagnostic: FrameDiagnostic.longSyncTask,
        suggestions: [
          'move heavy parsing/compute to a background isolate',
          'chunk work across frames with schedulers',
          'cache results to avoid repeating expensive sync work',
        ],
      );

  /// Oversized image guidance.
  factory Recommendation.oversizedImage() => const Recommendation(
        diagnostic: FrameDiagnostic.oversizedImage,
        suggestions: [
          'decode images closer to display size (cacheWidth/cacheHeight)',
          'provide resolution-appropriate assets',
          'avoid decoding large images during animations',
        ],
      );

  /// JSON map.
  Map<String, Object?> toJson() => {
        'diagnostic': diagnostic.id,
        'suggestions': suggestions,
      };

  /// Restores from JSON.
  factory Recommendation.fromJson(Map<String, Object?> json) {
    final id = json['diagnostic'] as String? ?? '';
    final diagnostic = FrameDiagnostic.values.firstWhere(
      (d) => d.id == id,
      orElse: () => FrameDiagnostic.debugModeMeasurement,
    );
    return Recommendation(
      diagnostic: diagnostic,
      suggestions: (json['suggestions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
