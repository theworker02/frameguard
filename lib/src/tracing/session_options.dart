import 'package:frameguard/src/core/sampling_mode.dart';
import 'package:meta/meta.dart';

/// Options controlling what a [FrameGuardSession] captures.
@immutable
class FrameGuardSessionOptions {
  /// Creates session options.
  const FrameGuardSessionOptions({
    this.warmup = Duration.zero,
    this.warmupFrames = 0,
    this.captureFrameTimings = true,
    this.captureRebuilds = true,
    this.captureGcSignals = false,
    this.captureImages = false,
    this.captureTimelineEvents = true,
    this.maxFrames = 10000,
    this.ringBuffer = true,
    this.waitForStableFrames = 0,
    this.syncTaskBudget = const Duration(milliseconds: 8),
  });

  /// Derives options from a [SamplingMode].
  factory FrameGuardSessionOptions.fromSamplingMode(
    SamplingMode mode, {
    Duration warmup = Duration.zero,
    int warmupFrames = 0,
    int maxFrames = 10000,
  }) {
    return FrameGuardSessionOptions(
      warmup: warmup,
      warmupFrames: warmupFrames,
      captureFrameTimings: true,
      captureRebuilds: mode.captureRebuilds,
      captureGcSignals: mode.captureGcSignals,
      captureImages: mode.captureImages,
      captureTimelineEvents: mode.captureTimelineEvents,
      maxFrames: maxFrames,
    );
  }

  /// Wall-clock warmup before frames count toward metrics.
  final Duration warmup;

  /// Number of initial frames to discard from metrics.
  final int warmupFrames;

  /// Capture Flutter [FrameTiming] callbacks.
  final bool captureFrameTimings;

  /// Capture [FrameGuardRegion] rebuild counts.
  final bool captureRebuilds;

  /// Attempt GC / memory pressure signals when available.
  final bool captureGcSignals;

  /// Capture image diagnostics when enabled.
  final bool captureImages;

  /// Emit `dart:developer` timeline sync events.
  final bool captureTimelineEvents;

  /// Maximum frames retained (bounded memory).
  final int maxFrames;

  /// Drop oldest frames when [maxFrames] is exceeded.
  final bool ringBuffer;

  /// Wait for this many consecutive healthy frames before measuring.
  final int waitForStableFrames;

  /// UI-thread budget for [FrameGuard.measureTask].
  final Duration syncTaskBudget;
}
