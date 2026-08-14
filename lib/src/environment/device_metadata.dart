import 'package:frameguard/src/environment/build_mode.dart';

/// Device and runtime metadata attached to every report.
///
/// Avoids unnecessary identifiers. All fields are optional when unavailable.
/// This DTO is Dart-only so CLI tooling can load reports without Flutter.
class DeviceMetadata {
  /// Creates metadata.
  const DeviceMetadata({
    required this.platform,
    this.osVersion,
    this.deviceModel,
    this.flutterVersion,
    this.dartVersion,
    required this.buildMode,
    required this.refreshRateHz,
    this.refreshRateFallback = false,
    this.logicalWidth,
    this.logicalHeight,
    this.devicePixelRatio,
  });

  /// Platform label (`android`, `ios`, `web`, `windows`, ...).
  final String platform;

  /// OS version when available.
  final String? osVersion;

  /// Device model when available.
  final String? deviceModel;

  /// Flutter framework version when known.
  final String? flutterVersion;

  /// Dart SDK version.
  final String? dartVersion;

  /// Build mode at capture time.
  final FrameGuardBuildMode buildMode;

  /// Effective refresh rate used for budgets.
  final double refreshRateHz;

  /// True when [refreshRateHz] came from the configured fallback.
  final bool refreshRateFallback;

  /// Logical viewport width.
  final double? logicalWidth;

  /// Logical viewport height.
  final double? logicalHeight;

  /// Device pixel ratio.
  final double? devicePixelRatio;

  /// JSON DTO.
  Map<String, Object?> toJson() => {
        'platform': platform,
        if (osVersion != null) 'osVersion': osVersion,
        if (deviceModel != null) 'deviceModel': deviceModel,
        if (flutterVersion != null) 'flutterVersion': flutterVersion,
        if (dartVersion != null) 'dartVersion': dartVersion,
        'buildMode': buildMode.name,
        'refreshRateHz': refreshRateHz,
        'refreshRateFallback': refreshRateFallback,
        if (logicalWidth != null) 'logicalWidth': logicalWidth,
        if (logicalHeight != null) 'logicalHeight': logicalHeight,
        if (devicePixelRatio != null) 'devicePixelRatio': devicePixelRatio,
      };

  /// Parses from JSON.
  factory DeviceMetadata.fromJson(Map<String, Object?> json) {
    return DeviceMetadata(
      platform: json['platform'] as String? ?? 'unknown',
      osVersion: json['osVersion'] as String?,
      deviceModel: json['deviceModel'] as String?,
      flutterVersion: json['flutterVersion'] as String?,
      dartVersion: json['dartVersion'] as String?,
      buildMode: FrameGuardBuildMode.values.firstWhere(
        (m) => m.name == json['buildMode'],
        orElse: () => FrameGuardBuildMode.unknown,
      ),
      refreshRateHz: (json['refreshRateHz'] as num?)?.toDouble() ?? 60,
      refreshRateFallback: json['refreshRateFallback'] as bool? ?? true,
      logicalWidth: (json['logicalWidth'] as num?)?.toDouble(),
      logicalHeight: (json['logicalHeight'] as num?)?.toDouble(),
      devicePixelRatio: (json['devicePixelRatio'] as num?)?.toDouble(),
    );
  }

  /// Short text for reports.
  String summary() {
    final buf = StringBuffer(platform);
    buf.write(' · ${refreshRateHz.toStringAsFixed(0)} Hz');
    if (refreshRateFallback) buf.write(' (fallback)');
    buf.write(' · ${buildMode.name}');
    return buf.toString();
  }
}
