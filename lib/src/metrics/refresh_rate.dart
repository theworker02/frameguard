/// How FrameGuard resolves the target frame interval.
sealed class RefreshRate {
  /// Creates a refresh-rate strategy.
  const RefreshRate();

  /// Attempt detection; fall back to config default when unavailable.
  static const RefreshRate auto = _AutoRefreshRate();

  /// Explicit Hertz value (e.g. 60, 90, 120, 144).
  const factory RefreshRate.hz(double hz) = ExplicitRefreshRate;

  /// Target frame budget for this strategy at [fallbackHz] when auto fails.
  Duration frameBudget({required double fallbackHz});

  /// Hertz used for reporting (may be the fallback).
  double effectiveHz({required double fallbackHz});

  /// Whether the rate came from a fallback rather than detection/override.
  bool get usedFallback;
}

class _AutoRefreshRate extends RefreshRate {
  const _AutoRefreshRate();

  @override
  Duration frameBudget({required double fallbackHz}) =>
      Duration(microseconds: (1e6 / fallbackHz).round());

  @override
  double effectiveHz({required double fallbackHz}) => fallbackHz;

  @override
  bool get usedFallback => true;
}

/// Explicit refresh rate override.
class ExplicitRefreshRate extends RefreshRate {
  /// Creates an explicit rate in Hertz.
  const ExplicitRefreshRate(this.hz);

  /// Frames per second.
  final double hz;

  @override
  Duration frameBudget({required double fallbackHz}) =>
      Duration(microseconds: (1e6 / hz).round());

  @override
  double effectiveHz({required double fallbackHz}) => hz;

  @override
  bool get usedFallback => false;
}
