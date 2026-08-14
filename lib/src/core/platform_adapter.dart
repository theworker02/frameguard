import 'package:frameguard/src/core/capabilities.dart';

/// Platform-specific diagnostic adapter.
///
/// FrameGuard never assumes every signal exists everywhere. Adapters declare
/// capabilities and optionally supply platform metrics. Default is a no-op
/// stub that reports unavailable native signals.
abstract class FrameGuardPlatformAdapter {
  /// Human-readable platform name.
  String get name;

  /// Capability overrides/merges for this platform.
  FrameGuardCapabilities get capabilities;

  /// Optional native metric snapshot (may be empty).
  Map<String, Object?> nativeMetrics();

  /// Best-effort refresh rate in Hz, or null if unknown.
  double? detectRefreshRateHz();
}

/// Default adapter used when no platform-specific integration is registered.
class DefaultPlatformAdapter implements FrameGuardPlatformAdapter {
  /// Creates the default adapter.
  const DefaultPlatformAdapter();

  @override
  String get name => 'default';

  @override
  FrameGuardCapabilities get capabilities => FrameGuardCapabilities.detect();

  @override
  Map<String, Object?> nativeMetrics() => const {
        'androidJankStats': 'Unavailable',
        'iosSignposts': 'Unavailable',
        'gpuCounters': 'Unavailable',
        'shaderDiagnostics': 'Unavailable',
      };

  @override
  double? detectRefreshRateHz() => null;
}

/// Android-oriented adapter placeholder.
///
/// Future: JankStats integration. Does not fabricate values today.
class AndroidPlatformAdapter implements FrameGuardPlatformAdapter {
  /// Creates the adapter.
  const AndroidPlatformAdapter();

  @override
  String get name => 'android';

  @override
  FrameGuardCapabilities get capabilities => const FrameGuardCapabilities(
        frameTimings: true,
        memorySignals: false,
        imageCacheMetrics: true,
        timelineTracing: true,
        refreshRateDetection: false,
        shaderDiagnostics: false,
        gcEvents: false,
      );

  @override
  Map<String, Object?> nativeMetrics() => const {
        'androidJankStats': 'Unavailable',
        'note': 'JankStats integration is a roadmap item. '
            'Frame timing uses SchedulerBinding FrameTiming.',
      };

  @override
  double? detectRefreshRateHz() => null;
}

/// iOS-oriented adapter placeholder (signposts roadmap).
class IosPlatformAdapter implements FrameGuardPlatformAdapter {
  /// Creates the adapter.
  const IosPlatformAdapter();

  @override
  String get name => 'ios';

  @override
  FrameGuardCapabilities get capabilities => const FrameGuardCapabilities(
        frameTimings: true,
        memorySignals: false,
        imageCacheMetrics: true,
        timelineTracing: true,
        refreshRateDetection: false,
        shaderDiagnostics: false,
        gcEvents: false,
      );

  @override
  Map<String, Object?> nativeMetrics() => const {
        'iosSignposts': 'Unavailable',
      };

  @override
  double? detectRefreshRateHz() => null;
}

/// Web-oriented adapter — avoids native-only assumptions.
class WebPlatformAdapter implements FrameGuardPlatformAdapter {
  /// Creates the adapter.
  const WebPlatformAdapter();

  @override
  String get name => 'web';

  @override
  FrameGuardCapabilities get capabilities => const FrameGuardCapabilities(
        frameTimings: true,
        memorySignals: false,
        imageCacheMetrics: true,
        timelineTracing: true,
        refreshRateDetection: false,
        shaderDiagnostics: false,
        gcEvents: false,
      );

  @override
  Map<String, Object?> nativeMetrics() => const {
        'note': 'Flutter web frame timings differ from native. '
            'Treat absolute ms budgets cautiously across browsers.',
      };

  @override
  double? detectRefreshRateHz() => null;
}

/// Registry for the active platform adapter.
class PlatformAdapters {
  PlatformAdapters._();

  static FrameGuardPlatformAdapter _active = const DefaultPlatformAdapter();

  /// Currently active adapter.
  static FrameGuardPlatformAdapter get active => _active;

  /// Registers an adapter (tests / future platform plugins).
  static void register(FrameGuardPlatformAdapter adapter) {
    _active = adapter;
  }

  /// Restores the default adapter.
  static void reset() {
    _active = const DefaultPlatformAdapter();
  }
}
