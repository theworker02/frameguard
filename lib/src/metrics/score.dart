import 'package:frameguard/src/metrics/frame_stats.dart';

/// Optional transparent performance score (secondary to raw metrics).
///
/// Score is decomposable and never replaces measured facts.
class FrameGuardScore {
  /// Creates a score breakdown.
  const FrameGuardScore({
    required this.total,
    required this.maxTotal,
    required this.frameSmoothness,
    required this.tailLatency,
    required this.consistency,
    required this.rebuildEfficiency,
  });

  /// Total points earned.
  final int total;

  /// Maximum possible points.
  final int maxTotal;

  /// Smoothness component (max 40).
  final int frameSmoothness;

  /// Tail latency component (max 30).
  final int tailLatency;

  /// Consistency component (max 20).
  final int consistency;

  /// Rebuild efficiency component (max 10).
  final int rebuildEfficiency;

  /// Computes a score from [stats] and optional rebuild pressure.
  ///
  /// Heuristic and documented — prefer raw percentiles for CI gates.
  factory FrameGuardScore.compute(
    FrameStats stats, {
    double? peakRebuildsPerFrame,
    Duration? targetFrame,
  }) {
    final budget = targetFrame ?? const Duration(milliseconds: 16);

    final jankPenalty = (stats.jankRate * 400).clamp(0, 40).round();
    final smoothness = 40 - jankPenalty;

    var tail = 30;
    if (stats.p95 > budget * 1.5) {
      tail -= 10;
    } else if (stats.p95 > budget) {
      tail -= 5;
    }
    if (stats.p99 > budget * 2) {
      tail -= 10;
    } else if (stats.p99 > budget * 1.5) {
      tail -= 5;
    }
    if (stats.jankDistribution.severe > 0) {
      tail -= 5;
    }
    tail = tail.clamp(0, 30);

    var cons = 20;
    if (stats.longestJankStreak >= 5) {
      cons -= 10;
    } else if (stats.longestJankStreak >= 3) {
      cons -= 5;
    }
    if (stats.stdDev > budget) {
      cons -= 5;
    }
    cons = cons.clamp(0, 20);

    var rebuild = 10;
    if (peakRebuildsPerFrame != null) {
      if (peakRebuildsPerFrame >= 10) {
        rebuild = 2;
      } else if (peakRebuildsPerFrame >= 5) {
        rebuild = 5;
      } else if (peakRebuildsPerFrame >= 3) {
        rebuild = 7;
      }
    }

    return FrameGuardScore(
      total: smoothness + tail + cons + rebuild,
      maxTotal: 100,
      frameSmoothness: smoothness,
      tailLatency: tail,
      consistency: cons,
      rebuildEfficiency: rebuild,
    );
  }

  /// Text breakdown.
  String summary() {
    final buf = StringBuffer()
      ..writeln('FrameGuard Score: $total / $maxTotal')
      ..writeln('Frame smoothness:    $frameSmoothness/40')
      ..writeln('Tail latency:        $tailLatency/30')
      ..writeln('Consistency:         $consistency/20')
      ..writeln('Rebuild efficiency:  $rebuildEfficiency/10');
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'total': total,
        'maxTotal': maxTotal,
        'frameSmoothness': frameSmoothness,
        'tailLatency': tailLatency,
        'consistency': consistency,
        'rebuildEfficiency': rebuildEfficiency,
      };
}
