import 'package:frameguard/src/diagnostics/diagnostic_id.dart';

/// Registry of suppressed diagnostics for the current zone/scope.
class DiagnosticSuppression {
  DiagnosticSuppression._();

  static final Set<FrameDiagnostic> _suppressed = {};

  /// Suppresses [diagnostics] until [clear] or [unsuppress].
  static void suppress(Set<FrameDiagnostic> diagnostics) {
    _suppressed.addAll(diagnostics);
  }

  /// Removes suppression for [diagnostics].
  static void unsuppress(Set<FrameDiagnostic> diagnostics) {
    _suppressed.removeAll(diagnostics);
  }

  /// Clears all suppressions.
  static void clear() => _suppressed.clear();

  /// Whether [diagnostic] is currently suppressed.
  static bool isSuppressed(FrameDiagnostic diagnostic) =>
      _suppressed.contains(diagnostic);

  /// Current set (unmodifiable view).
  static Set<FrameDiagnostic> get current => Set.unmodifiable(_suppressed);
}
