/// Capability discovery for the current platform/runtime.
///
/// FrameGuard never fabricates metrics. When a capability is unavailable,
/// reports state `Unavailable` rather than zeros.
class FrameGuardCapabilities {
  /// Creates a capability snapshot.
  const FrameGuardCapabilities({
    this.frameTimings = true,
    this.memorySignals = false,
    this.imageCacheMetrics = true,
    this.timelineTracing = true,
    this.refreshRateDetection = false,
    this.shaderDiagnostics = false,
    this.gcEvents = false,
  });

  /// Best-effort defaults for the current Flutter runtime.
  factory FrameGuardCapabilities.detect() {
    // Frame timings via SchedulerBinding are available on all Flutter targets.
    // Refresh-rate detection and GC events are not reliably exposed via public
    // APIs on all platforms — report conservatively.
    return const FrameGuardCapabilities(
      frameTimings: true,
      memorySignals: false,
      imageCacheMetrics: true,
      timelineTracing: true,
      refreshRateDetection: false,
      shaderDiagnostics: false,
      gcEvents: false,
    );
  }

  /// `SchedulerBinding.addTimingsCallback` / `FrameTiming` available.
  final bool frameTimings;

  /// Process memory growth signals available.
  final bool memorySignals;

  /// `PaintingBinding.instance.imageCache` metrics available.
  final bool imageCacheMetrics;

  /// `dart:developer` Timeline APIs available.
  final bool timelineTracing;

  /// Platform refresh rate can be detected (vs configured/fallback).
  final bool refreshRateDetection;

  /// Direct shader-compilation signals available (rarely true).
  final bool shaderDiagnostics;

  /// Precise GC pause events available.
  final bool gcEvents;

  /// Human-readable summary for reports.
  String describeUnavailable() {
    final missing = <String>[];
    if (!memorySignals) missing.add('memorySignals');
    if (!refreshRateDetection) missing.add('refreshRateDetection');
    if (!shaderDiagnostics) missing.add('shaderDiagnostics');
    if (!gcEvents) missing.add('gcEvents');
    if (missing.isEmpty) return 'All primary capabilities available.';
    return 'Unavailable: ${missing.join(', ')}';
  }
}
