import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:frameguard/src/core/frameguard.dart';
import 'package:frameguard/src/metrics/jank.dart';

/// Optional runtime performance overlay.
///
/// Disabled in release builds unless [FrameGuardConfig.enableOverlayInRelease]
/// is true or [forceEnable] is set.
class FrameGuardOverlay extends StatefulWidget {
  /// Creates an overlay wrapper.
  const FrameGuardOverlay({
    super.key,
    required this.child,
    this.compact = false,
    this.forceEnable = false,
  });

  /// App content.
  final Widget child;

  /// Compact "FG 120Hz / 8.1ms / JANK 0.4%" mode.
  final bool compact;

  /// Force-enable even in release.
  final bool forceEnable;

  @override
  State<FrameGuardOverlay> createState() => _FrameGuardOverlayState();
}

class _FrameGuardOverlayState extends State<FrameGuardOverlay> {
  TimingsCallback? _callback;
  Duration _lastFrame = Duration.zero;
  var _frames = 0;
  var _janky = 0;
  Duration _p95Estimate = Duration.zero;
  Duration _worst = Duration.zero;
  final List<Duration> _recent = [];

  bool get _enabled {
    if (widget.forceEnable) return true;
    if (kReleaseMode) {
      return FrameGuard.isInitialized &&
          FrameGuard.instance.config.enableOverlayInRelease;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      _callback = _onTimings;
      SchedulerBinding.instance.addTimingsCallback(_callback!);
    }
  }

  @override
  void dispose() {
    if (_callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_callback!);
    }
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted) return;
    final budget = FrameGuard.isInitialized
        ? FrameGuard.instance.config.refreshRate.frameBudget(
            fallbackHz: FrameGuard.instance.config.refreshRateFallbackHz,
          )
        : const Duration(milliseconds: 16);
    final policy = FrameGuard.isInitialized
        ? FrameGuard.instance.config.jankPolicy
        : const JankPolicy();

    for (final t in timings) {
      final total = t.totalSpan;
      _lastFrame = total;
      _frames++;
      if (JankPolicy.isJanky(policy.classify(total, budget))) {
        _janky++;
      }
      if (total > _worst) _worst = total;
      _recent.add(total);
      if (_recent.length > 120) _recent.removeAt(0);
    }
    if (_recent.isNotEmpty) {
      final sorted = [..._recent]..sort();
      final idx = ((sorted.length - 1) * 0.95).round();
      _p95Estimate = sorted[idx];
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    final hz = FrameGuard.isInitialized
        ? FrameGuard.instance.config.refreshRate.effectiveHz(
            fallbackHz: FrameGuard.instance.config.refreshRateFallbackHz,
          )
        : 60.0;
    final jankPct = _frames == 0 ? 0.0 : (_janky / _frames) * 100;
    final ms = (_lastFrame.inMicroseconds / 1000).toStringAsFixed(1);
    final p95 = (_p95Estimate.inMicroseconds / 1000).toStringAsFixed(1);
    final worst = (_worst.inMicroseconds / 1000).toStringAsFixed(1);

    final text = widget.compact
        ? 'FG ${hz.toStringAsFixed(0)}Hz\n$ms ms\nJANK ${jankPct.toStringAsFixed(1)}%'
        : 'FG ${hz.toStringAsFixed(0)}Hz  $ms ms\n'
            'P95 $p95  JANK ${jankPct.toStringAsFixed(1)}%\n'
            'Worst $worst  n=$_frames';

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          right: 8,
          top: 8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xCC111111),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFE8E8E8),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
