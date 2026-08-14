import 'package:frameguard/src/metrics/jank.dart';

/// Likely bottleneck for a single frame.
///
/// These are **derived classifications**, not measured certainty.
enum FrameBottleneck {
  /// Build duration dominates and exceeds a meaningful share of total.
  buildBound,

  /// Raster duration dominates.
  rasterBound,

  /// Both build and raster are significant.
  mixed,

  /// Not enough evidence to classify (e.g. both small, or total near zero).
  insufficientEvidence,
}

/// A single captured frame timing sample.
///
/// Sourced from Flutter [FrameTiming] via
/// `SchedulerBinding.instance.addTimingsCallback`. Do not substitute
/// wall-clock timers when this data is available.
class FrameSample {
  /// Creates a frame sample.
  const FrameSample({
    required this.frameNumber,
    required this.buildDuration,
    required this.rasterDuration,
    required this.totalDuration,
    required this.vsyncOverhead,
    required this.timestamp,
    required this.severity,
    required this.janky,
    required this.bottleneck,
    this.layerCount,
    this.eventIds = const [],
  });

  /// Monotonic frame counter within the session (post-warmup).
  final int frameNumber;

  /// Time spent building the frame (UI isolate / Dart).
  final Duration buildDuration;

  /// Time spent rasterizing the frame.
  final Duration rasterDuration;

  /// Total span of the frame (build + raster + overhead where applicable).
  final Duration totalDuration;

  /// Vsync overhead when provided by the engine.
  final Duration vsyncOverhead;

  /// Approximate wall-clock time when the frame was recorded.
  final DateTime timestamp;

  /// Severity relative to the session frame budget.
  final JankSeverity severity;

  /// Whether [severity] indicates a missed deadline.
  final bool janky;

  /// Likely bottleneck classification.
  final FrameBottleneck bottleneck;

  /// Optional layer count from [FrameTiming] when available.
  final int? layerCount;

  /// Custom event IDs that overlapped this frame.
  final List<String> eventIds;

  /// Classifies build vs raster contribution.
  ///
  /// Uses a dominance threshold: a side must be ≥ 55% of (build+raster)
  /// and at least 2ms to claim build/raster-bound; otherwise mixed or
  /// insufficient.
  static FrameBottleneck classifyBottleneck({
    required Duration build,
    required Duration raster,
    Duration minSignificant = const Duration(milliseconds: 2),
  }) {
    final buildUs = build.inMicroseconds;
    final rasterUs = raster.inMicroseconds;
    final sum = buildUs + rasterUs;
    if (sum <= 0) return FrameBottleneck.insufficientEvidence;
    if (build < minSignificant && raster < minSignificant) {
      return FrameBottleneck.insufficientEvidence;
    }
    final buildShare = buildUs / sum;
    final rasterShare = rasterUs / sum;
    if (buildShare >= 0.55 && build >= minSignificant) {
      return FrameBottleneck.buildBound;
    }
    if (rasterShare >= 0.55 && raster >= minSignificant) {
      return FrameBottleneck.rasterBound;
    }
    if (build >= minSignificant && raster >= minSignificant) {
      return FrameBottleneck.mixed;
    }
    return FrameBottleneck.insufficientEvidence;
  }

  /// Short label for timeline reports: B / R / M / ?.
  String get bottleneckLabel => switch (bottleneck) {
        FrameBottleneck.buildBound => 'B',
        FrameBottleneck.rasterBound => 'R',
        FrameBottleneck.mixed => 'M',
        FrameBottleneck.insufficientEvidence => '?',
      };

  /// JSON map (DTO-friendly).
  Map<String, Object?> toJson() => {
        'frameNumber': frameNumber,
        'buildMs': buildDuration.inMicroseconds / 1000.0,
        'rasterMs': rasterDuration.inMicroseconds / 1000.0,
        'totalMs': totalDuration.inMicroseconds / 1000.0,
        'vsyncOverheadMs': vsyncOverhead.inMicroseconds / 1000.0,
        'timestamp': timestamp.toIso8601String(),
        'severity': severity.name,
        'janky': janky,
        'bottleneck': bottleneck.name,
        if (layerCount != null) 'layerCount': layerCount,
        if (eventIds.isNotEmpty) 'eventIds': eventIds,
      };
}
