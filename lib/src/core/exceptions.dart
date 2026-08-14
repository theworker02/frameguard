/// Base class for FrameGuard errors with actionable messages.
class FrameGuardException implements Exception {
  /// Creates an exception with [message].
  FrameGuardException(this.message);

  /// Developer-facing explanation, including remediation when known.
  final String message;

  @override
  String toString() => 'FrameGuardException: $message';
}

/// Thrown when APIs are used before [FrameGuard.initialize].
class FrameGuardNotInitializedException extends FrameGuardException {
  /// Creates the exception.
  FrameGuardNotInitializedException()
      : super(
          'FrameGuard has not been initialized.\n'
          'Call FrameGuard.initialize() before startSession, trace, or mark.\n'
          'Example:\n'
          '  FrameGuard.initialize();\n'
          '  runApp(FrameGuardScope(child: MyApp()));',
        );
}

/// Thrown when a budget configuration is inconsistent.
class InvalidBudgetException extends FrameGuardException {
  /// Creates the exception.
  InvalidBudgetException(super.message);
}

/// Thrown when a requested metric is not available on this platform.
class UnsupportedMetricException extends FrameGuardException {
  /// Creates the exception.
  UnsupportedMetricException(String metric)
      : super(
          'Metric "$metric" is unavailable on this platform/runtime.\n'
          'FrameGuard reports Unavailable rather than fabricating values.\n'
          'Check FrameGuard.capabilities for supported signals.',
        );
}

/// Thrown when a baseline file cannot be parsed or fails schema checks.
class InvalidBaselineException extends FrameGuardException {
  /// Creates the exception.
  InvalidBaselineException(super.message);
}

/// Thrown in strict mode when baseline and current environments differ.
class EnvironmentMismatchException extends FrameGuardException {
  /// Creates the exception.
  EnvironmentMismatchException(super.message);
}

/// Thrown when a session is used after it has been stopped.
class SessionClosedException extends FrameGuardException {
  /// Creates the exception.
  SessionClosedException(String sessionId)
      : super(
          'Session "$sessionId" is already stopped and cannot accept events.',
        );
}

/// Thrown when a report schema version is unsupported.
class UnsupportedSchemaException extends FrameGuardException {
  /// Creates the exception.
  UnsupportedSchemaException({
    required int expected,
    required int found,
  }) : super(
          'Unable to read FrameGuard report.\n'
          'Expected schema version: $expected\n'
          'Found: $found\n'
          'Try:\n'
          '  dart run frameguard migrate report.json',
        );
}
