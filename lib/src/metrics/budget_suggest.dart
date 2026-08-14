import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/frame_stats.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Suggested [FrameBudget] derived from measured stats plus headroom.
///
/// Suggestions are **starting points**, not guarantees. Tighten after a few
/// healthy CI runs; never silently adopt production noise as a baseline.
class BudgetSuggestion {
  /// Creates a suggestion.
  const BudgetSuggestion({
    required this.budget,
    required this.headroom,
    required this.rationale,
  });

  /// Proposed budget.
  final FrameBudget budget;

  /// Relative headroom applied (e.g. `0.15` = +15%).
  final double headroom;

  /// Human-readable rationale lines.
  final List<String> rationale;

  /// Suggests a budget from [stats].
  ///
  /// [headroom] multiplies percentile ceilings (default +15%).
  /// Jank rate ceiling is `max(measured * (1+headroom), floorJankRate)`.
  factory BudgetSuggestion.fromStats(
    FrameStats stats, {
    double headroom = 0.15,
    double floorJankRate = 0.01,
    int? maxSevereJankFrames,
  }) {
    if (headroom < 0) {
      headroom = 0;
    }
    Duration pad(Duration d) {
      if (d == Duration.zero) {
        return const Duration(milliseconds: 16);
      }
      return Duration(
        microseconds: (d.inMicroseconds * (1 + headroom)).round(),
      );
    }

    final jankCeiling = (stats.jankRate * (1 + headroom)).clamp(0.0, 1.0);
    final maxJankRate =
        jankCeiling < floorJankRate ? floorJankRate : jankCeiling;

    final budget = FrameBudget(
      maxJankRate: maxJankRate,
      maxP50FrameTime: pad(stats.p50),
      maxP95FrameTime: pad(stats.p95),
      maxP99FrameTime: pad(stats.p99),
      maxFrameTime: pad(stats.max),
      maxSevereJankFrames: maxSevereJankFrames ?? 0,
    );

    final rationale = <String>[
      'Derived from ${stats.totalFrames} measured frames.',
      'Applied ${(headroom * 100).toStringAsFixed(0)}% headroom to percentile ceilings.',
      'Jank rate ceiling: ${(maxJankRate * 100).toStringAsFixed(2)}% '
          '(floor ${(floorJankRate * 100).toStringAsFixed(2)}%).',
      'Treat this as a draft — tighten after stable CI green runs.',
    ];

    return BudgetSuggestion(
      budget: budget,
      headroom: headroom,
      rationale: rationale,
    );
  }

  /// Suggests from a full [report].
  factory BudgetSuggestion.fromReport(
    FrameGuardReport report, {
    double headroom = 0.15,
    double floorJankRate = 0.01,
  }) {
    return BudgetSuggestion.fromStats(
      report.stats,
      headroom: headroom,
      floorJankRate: floorJankRate,
    );
  }

  /// Dart snippet for pasting into tests / config.
  String toDartSnippet() {
    String dur(Duration? d) {
      if (d == null) return 'null';
      final ms = d.inMicroseconds / 1000.0;
      if (ms == ms.roundToDouble()) {
        return 'const Duration(milliseconds: ${ms.round()})';
      }
      return 'Duration(microseconds: ${d.inMicroseconds})';
    }

    final b = budget;
    return '''
const budget = FrameBudget(
  maxJankRate: ${b.maxJankRate},
  maxP50FrameTime: ${dur(b.maxP50FrameTime)},
  maxP95FrameTime: ${dur(b.maxP95FrameTime)},
  maxP99FrameTime: ${dur(b.maxP99FrameTime)},
  maxFrameTime: ${dur(b.maxFrameTime)},
  maxSevereJankFrames: ${b.maxSevereJankFrames},
);
''';
  }

  /// YAML snippet for `frameguard.yaml`.
  String toYamlSnippet() {
    String ms(Duration? d) =>
        d == null ? 'null' : (d.inMicroseconds / 1000.0).toStringAsFixed(2);
    final b = budget;
    return '''
budgets:
  max_jank_rate: ${b.maxJankRate}
  max_p50_ms: ${ms(b.maxP50FrameTime)}
  max_p95_ms: ${ms(b.maxP95FrameTime)}
  max_p99_ms: ${ms(b.maxP99FrameTime)}
  max_frame_ms: ${ms(b.maxFrameTime)}
  max_severe_jank_frames: ${b.maxSevereJankFrames}
''';
  }

  /// Text summary.
  String summary() {
    String ms(Duration? d) => d == null
        ? '—'
        : '${(d.inMicroseconds / 1000.0).toStringAsFixed(1)} ms';
    final b = budget;
    final buf = StringBuffer()
      ..writeln(
        'Suggested FrameBudget '
        '(+${(headroom * 100).toStringAsFixed(0)}% headroom)',
      )
      ..writeln(
        '  maxJankRate=${b.maxJankRate}  '
        'p50≤${ms(b.maxP50FrameTime)}  '
        'p95≤${ms(b.maxP95FrameTime)}  '
        'p99≤${ms(b.maxP99FrameTime)}  '
        'max≤${ms(b.maxFrameTime)}',
      );
    for (final line in rationale) {
      buf.writeln('· $line');
    }
    return buf.toString().trimRight();
  }
}
