import 'package:frameguard/src/reporting/baseline.dart';

/// Optional historical drift analysis across ordered baselines.
class BaselineDrift {
  /// Creates a drift analysis.
  const BaselineDrift({
    required this.metric,
    required this.points,
    required this.totalRelativeChange,
    required this.gradualRegression,
  });

  /// Metric name (e.g. `p95FrameMs`).
  final String metric;

  /// Ordered historical points (oldest → newest).
  final List<DriftPoint> points;

  /// Relative change from first to last.
  final double totalRelativeChange;

  /// Whether a gradual regression was detected.
  final bool gradualRegression;

  /// Analyzes p95 drift across [baselines] (ordered oldest → newest).
  factory BaselineDrift.p95(
    List<FrameGuardBaseline> baselines, {
    double gradualThreshold = 0.20,
  }) {
    final points = [
      for (var i = 0; i < baselines.length; i++)
        DriftPoint(
          label: baselines[i].createdAt?.toIso8601String() ?? 'v$i',
          value: baselines[i].metrics.p95FrameMs,
        ),
    ];
    if (points.length < 2) {
      return BaselineDrift(
        metric: 'p95FrameMs',
        points: points,
        totalRelativeChange: 0,
        gradualRegression: false,
      );
    }
    final first = points.first.value;
    final last = points.last.value;
    final rel = first == 0 ? 0.0 : (last - first) / first;
    // Gradual: each step non-decreasing and total ≥ threshold.
    var nonDecreasing = true;
    for (var i = 1; i < points.length; i++) {
      if (points[i].value + 0.05 < points[i - 1].value) {
        nonDecreasing = false;
        break;
      }
    }
    return BaselineDrift(
      metric: 'p95FrameMs',
      points: points,
      totalRelativeChange: rel,
      gradualRegression: nonDecreasing && rel >= gradualThreshold,
    );
  }

  /// Text summary.
  String summary() {
    final buf = StringBuffer()..writeln('P95 trend');
    for (final p in points) {
      buf.writeln('${p.label.padRight(12)} ${p.value.toStringAsFixed(1)} ms');
    }
    if (gradualRegression) {
      buf.writeln();
      buf.writeln('Gradual regression detected:');
      buf.writeln(
        '+${(totalRelativeChange * 100).toStringAsFixed(0)}% over '
        '${points.length} baselines',
      );
    }
    return buf.toString().trimRight();
  }
}

/// A single historical metric point.
class DriftPoint {
  /// Creates a point.
  const DriftPoint({required this.label, required this.value});

  /// Label (version, date, etc.).
  final String label;

  /// Metric value.
  final double value;
}
