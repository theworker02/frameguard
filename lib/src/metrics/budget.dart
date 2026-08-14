import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/metrics/refresh_rate.dart';

/// Performance budget for a session or scenario.
///
/// Budgets are evaluated against measured facts (counts, percentiles).
/// Any null field is ignored during evaluation.
class FrameBudget {
  /// Creates a frame budget. All limits are optional; unspecified limits
  /// are not evaluated.
  const FrameBudget({
    this.maxJankFrames,
    this.maxJankRate,
    this.maxP50FrameTime,
    this.maxP95FrameTime,
    this.maxP99FrameTime,
    this.maxFrameTime,
    this.maxBuildDuration,
    this.maxRasterDuration,
    this.maxSevereJankFrames,
    this.maxAverageFrameTime,
  });

  /// Budget for a given refresh rate (frame time = 1000/hz ms).
  ///
  /// Sets p95 to 1× frame budget and p99 to 1.5× by default.
  factory FrameBudget.forRefreshRate(
    double hz, {
    int? maxJankFrames,
    double maxJankRate = 0.01,
    double p95Multiplier = 1.0,
    double p99Multiplier = 1.5,
  }) {
    if (hz <= 0) {
      throw InvalidBudgetException(
        'Refresh rate must be positive. Got: $hz',
      );
    }
    final frameUs = (1e6 / hz).round();
    return FrameBudget(
      maxJankFrames: maxJankFrames,
      maxJankRate: maxJankRate,
      maxP95FrameTime: Duration(
        microseconds: (frameUs * p95Multiplier).round(),
      ),
      maxP99FrameTime: Duration(
        microseconds: (frameUs * p99Multiplier).round(),
      ),
    );
  }

  /// Convenience using [RefreshRate].
  factory FrameBudget.forRefresh(
    RefreshRate rate, {
    required double fallbackHz,
    int? maxJankFrames,
    double maxJankRate = 0.01,
  }) {
    return FrameBudget.forRefreshRate(
      rate.effectiveHz(fallbackHz: fallbackHz),
      maxJankFrames: maxJankFrames,
      maxJankRate: maxJankRate,
    );
  }

  /// Maximum absolute count of janky frames.
  final int? maxJankFrames;

  /// Maximum jank rate (0–1), e.g. 0.01 = 1%.
  final double? maxJankRate;

  /// Maximum p50 total frame time.
  final Duration? maxP50FrameTime;

  /// Maximum p95 total frame time.
  final Duration? maxP95FrameTime;

  /// Maximum p99 total frame time.
  final Duration? maxP99FrameTime;

  /// Maximum single-frame total time.
  final Duration? maxFrameTime;

  /// Maximum average build duration across frames.
  final Duration? maxBuildDuration;

  /// Maximum average raster duration across frames.
  final Duration? maxRasterDuration;

  /// Maximum count of severe-jank frames.
  final int? maxSevereJankFrames;

  /// Maximum average total frame time.
  final Duration? maxAverageFrameTime;

  /// Validates consistency (e.g. rates in range).
  void validate() {
    if (maxJankRate != null && (maxJankRate! < 0 || maxJankRate! > 1)) {
      throw InvalidBudgetException(
        'maxJankRate must be between 0 and 1 inclusive. Got: $maxJankRate',
      );
    }
    if (maxJankFrames != null && maxJankFrames! < 0) {
      throw InvalidBudgetException('maxJankFrames must be ≥ 0.');
    }
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        if (maxJankFrames != null) 'maxJankFrames': maxJankFrames,
        if (maxJankRate != null) 'maxJankRate': maxJankRate,
        if (maxP50FrameTime != null)
          'maxP50FrameMs': maxP50FrameTime!.inMicroseconds / 1000.0,
        if (maxP95FrameTime != null)
          'maxP95FrameMs': maxP95FrameTime!.inMicroseconds / 1000.0,
        if (maxP99FrameTime != null)
          'maxP99FrameMs': maxP99FrameTime!.inMicroseconds / 1000.0,
        if (maxFrameTime != null)
          'maxFrameMs': maxFrameTime!.inMicroseconds / 1000.0,
        if (maxBuildDuration != null)
          'maxBuildMs': maxBuildDuration!.inMicroseconds / 1000.0,
        if (maxRasterDuration != null)
          'maxRasterMs': maxRasterDuration!.inMicroseconds / 1000.0,
        if (maxSevereJankFrames != null)
          'maxSevereJankFrames': maxSevereJankFrames,
        if (maxAverageFrameTime != null)
          'maxAverageFrameMs': maxAverageFrameTime!.inMicroseconds / 1000.0,
      };

  /// Parses from JSON DTO.
  factory FrameBudget.fromJson(Map<String, Object?> json) {
    Duration? ms(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is num) {
        return Duration(microseconds: (v * 1000).round());
      }
      return null;
    }

    return FrameBudget(
      maxJankFrames: (json['maxJankFrames'] as num?)?.toInt(),
      maxJankRate: (json['maxJankRate'] as num?)?.toDouble(),
      maxP50FrameTime: ms('maxP50FrameMs'),
      maxP95FrameTime: ms('maxP95FrameMs'),
      maxP99FrameTime: ms('maxP99FrameMs'),
      maxFrameTime: ms('maxFrameMs'),
      maxBuildDuration: ms('maxBuildMs'),
      maxRasterDuration: ms('maxRasterMs'),
      maxSevereJankFrames: (json['maxSevereJankFrames'] as num?)?.toInt(),
      maxAverageFrameTime: ms('maxAverageFrameMs'),
    );
  }
}

/// Rebuild budget for a named [FrameGuardRegion].
class RegionBudget {
  /// Creates a region budget.
  const RegionBudget({
    required this.region,
    this.maxRebuilds,
    this.maxRebuildsPerFrame,
    this.maxPeakRebuildsInFrame,
  });

  /// Region name matching [FrameGuardRegion.name].
  final String region;

  /// Maximum total rebuilds during the session.
  final int? maxRebuilds;

  /// Maximum average rebuilds per frame.
  final double? maxRebuildsPerFrame;

  /// Maximum rebuilds observed in a single frame.
  final int? maxPeakRebuildsInFrame;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'region': region,
        if (maxRebuilds != null) 'maxRebuilds': maxRebuilds,
        if (maxRebuildsPerFrame != null)
          'maxRebuildsPerFrame': maxRebuildsPerFrame,
        if (maxPeakRebuildsInFrame != null)
          'maxPeakRebuildsInFrame': maxPeakRebuildsInFrame,
      };
}
