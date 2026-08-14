import 'package:flutter/foundation.dart';
import 'package:frameguard/src/environment/build_mode.dart';

/// Detects the current build mode using Flutter foundation flags.
FrameGuardBuildMode detectBuildMode() {
  if (kReleaseMode) return FrameGuardBuildMode.release;
  if (kProfileMode) return FrameGuardBuildMode.profile;
  if (kDebugMode) return FrameGuardBuildMode.debug;
  return FrameGuardBuildMode.unknown;
}
