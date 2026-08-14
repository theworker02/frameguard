import 'package:flutter/widgets.dart';
import 'package:frameguard/src/diagnostics/diagnostic_id.dart';
import 'package:frameguard/src/diagnostics/suppression.dart';

/// Suppresses selected diagnostics for a subtree.
///
/// Use sparingly — suppression hides real signals.
class FrameGuardSuppress extends StatefulWidget {
  /// Creates a suppression scope.
  const FrameGuardSuppress({
    super.key,
    required this.diagnostics,
    required this.child,
  });

  /// Diagnostics to suppress while mounted.
  final Set<FrameDiagnostic> diagnostics;

  /// Child subtree.
  final Widget child;

  @override
  State<FrameGuardSuppress> createState() => _FrameGuardSuppressState();
}

class _FrameGuardSuppressState extends State<FrameGuardSuppress> {
  @override
  void initState() {
    super.initState();
    DiagnosticSuppression.suppress(widget.diagnostics);
  }

  @override
  void didUpdateWidget(covariant FrameGuardSuppress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diagnostics != widget.diagnostics) {
      DiagnosticSuppression.unsuppress(oldWidget.diagnostics);
      DiagnosticSuppression.suppress(widget.diagnostics);
    }
  }

  @override
  void dispose() {
    DiagnosticSuppression.unsuppress(widget.diagnostics);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
