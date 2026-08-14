/// Exit codes for FrameGuard CLI / CI.
abstract final class FrameGuardExitCode {
  /// Success / no regression.
  static const int pass = 0;

  /// Budget or baseline regression.
  static const int regression = 1;

  /// Invalid configuration or report.
  static const int invalid = 2;
}
