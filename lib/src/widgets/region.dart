import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:frameguard/src/core/frameguard.dart';
import 'package:frameguard/src/metrics/region_stats.dart';

/// Inherited region name for nesting.
class _RegionName extends InheritedWidget {
  const _RegionName({required this.name, required super.child});

  final String name;

  static String? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_RegionName>()?.name;
  }

  @override
  bool updateShouldNotify(_RegionName oldWidget) => name != oldWidget.name;
}

/// Instrumented diagnostic region for rebuild tracking.
///
/// Uses public Flutter APIs only. Rebuild counts are **measured facts**;
/// correlation with slow frames is a derived classification.
///
/// When [measureBuild] is true, a wall-clock proxy around `build` is recorded.
/// This is approximate and must not be treated as nanosecond-perfect
/// framework timing.
class FrameGuardRegion extends StatefulWidget {
  /// Creates a named region.
  const FrameGuardRegion({
    super.key,
    required this.name,
    required this.child,
    this.measureBuild = false,
  });

  /// Region name (appears in reports and heatmaps).
  final String name;

  /// Child subtree.
  final Widget child;

  /// Opt-in approximate build duration proxy.
  final bool measureBuild;

  @override
  State<FrameGuardRegion> createState() => _FrameGuardRegionState();
}

class _FrameGuardRegionState extends State<FrameGuardRegion> {
  RegionStatsAccumulator? _acc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(covariant FrameGuardRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      _bind();
    }
  }

  void _bind() {
    final session =
        FrameGuard.isInitialized ? FrameGuard.instance.activeSession : null;
    if (session == null || !session.options.captureRebuilds) {
      _acc = null;
      return;
    }
    _acc = session.region(widget.name);
    _acc!.measureBuild = widget.measureBuild;
    _acc!.parentName = _RegionName.maybeOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final sw = widget.measureBuild ? (Stopwatch()..start()) : null;
    // Count this build as a rebuild observation.
    final acc = _acc;
    if (acc != null) {
      // Defer to post-frame so we don't perturb build excessively.
      final proxy = sw;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Duration? d;
        if (proxy != null) {
          proxy.stop();
          d = proxy.elapsed;
        }
        acc.onRebuild(buildProxy: d);
      });
    }

    return _RegionName(
      name: widget.name,
      child: widget.child,
    );
  }
}
