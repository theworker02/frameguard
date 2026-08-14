import 'package:flutter/widgets.dart';
import 'package:frameguard/src/core/frameguard.dart';

/// Provides FrameGuard context to the widget tree.
///
/// Typically wraps the root app after [FrameGuard.initialize].
class FrameGuardScope extends StatefulWidget {
  /// Creates a scope.
  const FrameGuardScope({
    super.key,
    required this.child,
  });

  /// App subtree.
  final Widget child;

  /// Nearest scope state, if any.
  static FrameGuardScopeState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<FrameGuardScopeState>();
  }

  @override
  State<FrameGuardScope> createState() => FrameGuardScopeState();
}

/// State for [FrameGuardScope].
class FrameGuardScopeState extends State<FrameGuardScope> {
  @override
  void initState() {
    super.initState();
    if (!FrameGuard.isInitialized) {
      FrameGuard.initialize();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
