/// Severity of a janky frame relative to the target frame budget.
enum JankSeverity {
  /// Frame completed within budget.
  healthy,

  /// Frame exceeded budget but ≤ [JankPolicy.minorMultiplier] × budget.
  ///
  /// Note: minor starts at 1× budget (any miss) up to majorMultiplier.
  minor,

  /// Frame between major and severe multipliers.
  major,

  /// Frame exceeded [JankPolicy.severeMultiplier] × budget.
  severe,
}

/// Configurable multipliers for jank severity buckets.
///
/// Defaults:
/// - healthy: ≤ 1× budget
/// - minor: (1×, 2×]
/// - major: (2×, 4×]
/// - severe: > 4×
class JankPolicy {
  /// Creates a jank policy.
  const JankPolicy({
    this.minorMultiplier = 1.0,
    this.majorMultiplier = 2.0,
    this.severeMultiplier = 4.0,
  });

  /// Lower bound for minor jank (typically 1.0 = any missed deadline).
  final double minorMultiplier;

  /// Lower bound for major jank.
  final double majorMultiplier;

  /// Lower bound for severe jank.
  final double severeMultiplier;

  /// Classifies [frameDuration] against [budget].
  JankSeverity classify(Duration frameDuration, Duration budget) {
    if (budget <= Duration.zero) return JankSeverity.healthy;
    final ratio = frameDuration.inMicroseconds / budget.inMicroseconds;
    if (ratio <= minorMultiplier) return JankSeverity.healthy;
    if (ratio <= majorMultiplier) return JankSeverity.minor;
    if (ratio <= severeMultiplier) return JankSeverity.major;
    return JankSeverity.severe;
  }

  /// Whether the severity represents a missed frame deadline.
  static bool isJanky(JankSeverity severity) =>
      severity != JankSeverity.healthy;
}

/// Counts of frames in each severity bucket.
class JankDistribution {
  /// Creates a distribution.
  const JankDistribution({
    this.healthy = 0,
    this.minor = 0,
    this.major = 0,
    this.severe = 0,
  });

  /// Frames within budget.
  final int healthy;

  /// Minor jank frames.
  final int minor;

  /// Major jank frames.
  final int major;

  /// Severe jank frames.
  final int severe;

  /// Total frames.
  int get total => healthy + minor + major + severe;

  /// Total janky frames (any severity above healthy).
  int get janky => minor + major + severe;

  /// Builds a distribution from classified severities.
  factory JankDistribution.fromSeverities(Iterable<JankSeverity> severities) {
    var healthy = 0, minor = 0, major = 0, severe = 0;
    for (final s in severities) {
      switch (s) {
        case JankSeverity.healthy:
          healthy++;
        case JankSeverity.minor:
          minor++;
        case JankSeverity.major:
          major++;
        case JankSeverity.severe:
          severe++;
      }
    }
    return JankDistribution(
      healthy: healthy,
      minor: minor,
      major: major,
      severe: severe,
    );
  }

  /// JSON-friendly map.
  Map<String, int> toJson() => {
        'healthy': healthy,
        'minor': minor,
        'major': major,
        'severe': severe,
      };
}
