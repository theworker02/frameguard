import 'package:frameguard/src/metrics/budget.dart';

/// Named budget profile (e.g. `strict`, `mid_range`, `low_end`).
class BudgetProfile {
  /// Creates a profile.
  const BudgetProfile({
    required this.name,
    required this.budget,
    this.regionBudgets = const [],
    this.description,
  });

  /// Profile name.
  final String name;

  /// Frame budget for this profile.
  final FrameBudget budget;

  /// Optional per-region budgets.
  final List<RegionBudget> regionBudgets;

  /// Optional description.
  final String? description;

  /// Built-in profiles.
  static List<BudgetProfile> get builtins => [
        strict120(),
        midRange60(),
        lowEnd(),
        animation60(),
      ];

  /// Looks up a built-in profile by [name], or `null` if unknown.
  static BudgetProfile? byName(String name) {
    for (final p in builtins) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// Strict profile for high-end 120 Hz targets.
  static BudgetProfile strict120() => BudgetProfile(
        name: 'strict',
        description: 'Strict budgets for 120 Hz high-end devices.',
        budget: FrameBudget.forRefreshRate(
          120,
          maxJankFrames: 2,
          maxJankRate: 0.005,
        ),
      );

  /// Default mid-range 60 Hz profile.
  static BudgetProfile midRange60() => BudgetProfile(
        name: 'mid_range',
        description: 'Mid-range 60 Hz device class.',
        budget: FrameBudget.forRefreshRate(
          60,
          maxJankFrames: 5,
          maxJankRate: 0.02,
          p95Multiplier: 1.1,
          p99Multiplier: 1.8,
        ),
      );

  /// Lenient legacy / low-end profile.
  static BudgetProfile lowEnd() => BudgetProfile(
        name: 'low_end',
        description: 'Lenient budgets for low-end devices.',
        budget: FrameBudget.forRefreshRate(
          60,
          maxJankFrames: 15,
          maxJankRate: 0.05,
          p95Multiplier: 1.5,
          p99Multiplier: 2.5,
        ),
      );

  /// Animation-focused 60 Hz profile (slightly tighter p95).
  static BudgetProfile animation60() => BudgetProfile(
        name: 'animation',
        description: 'Animation / transition scenarios at 60 Hz.',
        budget: FrameBudget.forRefreshRate(
          60,
          maxJankFrames: 3,
          maxJankRate: 0.01,
          p95Multiplier: 1.0,
          p99Multiplier: 1.5,
        ),
      );
}
