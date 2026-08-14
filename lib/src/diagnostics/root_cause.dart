import 'package:frameguard/src/diagnostics/diagnostic_id.dart';

/// Category for root-cause ranking.
enum ContributorCategory {
  /// Build / Dart UI work.
  build,

  /// Raster / GPU-side work.
  raster,

  /// Rebuild storms.
  rebuilds,

  /// Synchronous tasks.
  syncWork,

  /// Image decode / size issues.
  images,

  /// Memory / GC pressure.
  memory,

  /// Baseline comparison.
  baseline,

  /// Other / mixed.
  other,
}

/// A ranked likely contributor with categorical confidence.
class RootCauseContributor {
  /// Creates a contributor.
  const RootCauseContributor({
    required this.title,
    required this.confidence,
    required this.category,
  });

  /// Short title.
  final String title;

  /// low / medium / high — never fake precision.
  final DiagnosticConfidence confidence;

  /// Category for filtering.
  final ContributorCategory category;

  /// Formats a numbered list for reports.
  static String formatList(List<RootCauseContributor> items) {
    final buf = StringBuffer('LIKELY CONTRIBUTORS\n');
    for (var i = 0; i < items.length; i++) {
      final c = items[i];
      buf.writeln('${i + 1}. ${c.title}');
      buf.writeln('   confidence: ${c.confidence.name}');
    }
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'title': title,
        'confidence': confidence.name,
        'category': category.name,
      };

  /// Restores from JSON.
  factory RootCauseContributor.fromJson(Map<String, Object?> json) {
    return RootCauseContributor(
      title: json['title'] as String? ?? 'unknown',
      confidence: DiagnosticConfidence.values.firstWhere(
        (c) => c.name == json['confidence'],
        orElse: () => DiagnosticConfidence.low,
      ),
      category: ContributorCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ContributorCategory.other,
      ),
    );
  }
}
