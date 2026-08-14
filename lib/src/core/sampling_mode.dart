/// Sampling modes that trade diagnostic depth for overhead.
enum SamplingMode {
  /// Capture all supported signals (frames, rebuilds, images, markers).
  full,

  /// Capture frames, rebuilds, and markers; skip heavier image/GC probes.
  balanced,

  /// Capture only inexpensive frame timings and markers.
  lightweight,
}

/// Extension helpers for [SamplingMode].
extension SamplingModeX on SamplingMode {
  /// Whether rebuild region tracking is enabled.
  bool get captureRebuilds =>
      this == SamplingMode.full || this == SamplingMode.balanced;

  /// Whether image diagnostics are enabled.
  bool get captureImages => this == SamplingMode.full;

  /// Whether GC / memory pressure probes are enabled.
  bool get captureGcSignals => this == SamplingMode.full;

  /// Whether timeline events are recorded via `dart:developer`.
  bool get captureTimelineEvents => this != SamplingMode.lightweight;
}
