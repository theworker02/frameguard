/// Build mode awareness for performance reports.
enum FrameGuardBuildMode {
  /// Debug mode — timings do not represent production.
  debug,

  /// Profile mode — recommended for local performance work.
  profile,

  /// Release mode — closest to production.
  release,

  /// Unknown / test environment.
  unknown,
}

/// Warning text when measuring in debug mode.
String? debugModeWarning(FrameGuardBuildMode mode) {
  if (mode != FrameGuardBuildMode.debug) return null;
  return 'WARNING\n'
      'This report was captured in DEBUG mode.\n'
      'Frame timing measurements may not represent production performance.\n'
      'Recommended:\n'
      'profile or release mode';
}
