import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:frameguard/src/environment/build_mode.dart';
import 'package:frameguard/src/environment/build_mode_detect.dart';
import 'package:frameguard/src/environment/device_metadata.dart';

/// Captures best-effort [DeviceMetadata] from the current Flutter binding.
DeviceMetadata captureDeviceMetadata({
  required double refreshRateHz,
  required bool refreshRateFallback,
  FrameGuardBuildMode? buildMode,
}) {
  double? logicalWidth;
  double? logicalHeight;
  double? dpr;
  try {
    final views = ui.PlatformDispatcher.instance.views;
    if (views.isNotEmpty) {
      final view = views.first;
      dpr = view.devicePixelRatio;
      final physical = view.physicalSize;
      if (dpr > 0) {
        logicalWidth = physical.width / dpr;
        logicalHeight = physical.height / dpr;
      }
    }
  } catch (_) {
    // Headless / test environments may lack views.
  }

  return DeviceMetadata(
    platform: _platformName(),
    osVersion: null,
    deviceModel: null,
    flutterVersion: null,
    dartVersion: null,
    buildMode: buildMode ?? detectBuildMode(),
    refreshRateHz: refreshRateHz,
    refreshRateFallback: refreshRateFallback,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: dpr,
  );
}

String _platformName() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}
