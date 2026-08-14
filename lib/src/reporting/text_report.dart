import 'package:frameguard/src/metrics/frame_sample.dart';
import 'package:frameguard/src/metrics/jank.dart';
import 'package:frameguard/src/metrics/region_stats.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Formats [FrameGuardReport] for terminals (no color required).
class TextReportFormatter {
  /// Creates a formatter.
  TextReportFormatter(this.report);

  /// Source report.
  final FrameGuardReport report;

  static String _ms(Duration d) =>
      '${(d.inMicroseconds / 1000.0).toStringAsFixed(1)} ms';

  /// Short summary block.
  String summary() {
    final r = report;
    final buf = StringBuffer()
      ..writeln('FRAMEGUARD REPORT')
      ..writeln('Scenario:')
      ..writeln(r.scenario)
      ..writeln('Device:')
      ..writeln(r.device.summary())
      ..writeln('${r.refreshRateHz.toStringAsFixed(0)} Hz target')
      ..writeln('Result:')
      ..writeln(r.passed ? 'PASS' : 'FAIL')
      ..writeln('Frames:')
      ..writeln('${r.stats.totalFrames}')
      ..writeln('Jank:')
      ..writeln('${r.stats.jankyFrames}')
      ..writeln('P95:')
      ..writeln(_ms(r.stats.p95))
      ..writeln('P99:')
      ..writeln(_ms(r.stats.p99));
    if (r.explanation != null) {
      buf.writeln('Primary issue:');
      buf.writeln(r.explanation!.primaryFinding);
      if (r.regions.isNotEmpty) {
        final suspicious = [...r.regions]
          ..sort((a, b) => b.rebuilds.compareTo(a.rebuilds));
        buf.writeln('Most suspicious region:');
        buf.writeln(suspicious.first.name);
      }
    }
    if (r.debugModeWarning != null) {
      buf.writeln();
      buf.writeln(r.debugModeWarning);
    }
    return buf.toString().trimRight();
  }

  /// Full multi-section report.
  String full() {
    final r = report;
    final buf = StringBuffer()
      ..writeln(summary())
      ..writeln()
      ..writeln(r.stats.summary())
      ..writeln()
      ..writeln('JANK DISTRIBUTION')
      ..writeln('healthy: ${r.stats.jankDistribution.healthy}')
      ..writeln('minor:   ${r.stats.jankDistribution.minor}')
      ..writeln('major:   ${r.stats.jankDistribution.major}')
      ..writeln('severe:  ${r.stats.jankDistribution.severe}')
      ..writeln()
      ..writeln('FRAME HISTOGRAM')
      ..writeln(r.stats.histogram.toAscii());

    if (r.regions.isNotEmpty) {
      buf.writeln();
      buf.writeln(_rebuildHeatmap(r.regions));
    }

    if (r.budgetEvaluation != null) {
      buf.writeln();
      buf.writeln(r.budgetEvaluation!.summary());
    }

    if (r.explanation != null) {
      buf.writeln();
      buf.writeln(r.explanation!.summary());
    }

    for (final task in r.tasks.where((t) => t.exceededBudget)) {
      buf.writeln();
      buf.writeln(task.summary());
    }

    for (final img in r.imageWarnings) {
      buf.writeln();
      buf.writeln(img.summary());
    }

    if (r.imageCache != null) {
      buf.writeln();
      buf.writeln(r.imageCache!.summary());
    }

    buf.writeln();
    buf.writeln(frameTimeline(limit: 40));

    buf.writeln();
    buf.writeln(r.score.summary());

    return buf.toString().trimRight();
  }

  /// Compact frame timeline.
  String frameTimeline({int? limit}) {
    final frames = report.frames;
    final slice = limit == null ? frames : frames.take(limit).toList();
    final buf = StringBuffer('FRAME TIMELINE\n');
    for (final f in slice) {
      final label = _severityLabel(f);
      final ms = (f.totalDuration.inMicroseconds / 1000.0)
          .toStringAsFixed(1)
          .padLeft(6);
      buf.writeln(
        '${f.frameNumber.toString().padLeft(5)}  $ms ms  $label  ${f.bottleneckLabel}',
      );
    }
    if (limit != null && frames.length > limit) {
      buf.writeln('... (${frames.length - limit} more frames)');
    }
    buf.writeln();
    buf.writeln(
        'B = build-bound  R = raster-bound  M = mixed  ? = insufficient');
    return buf.toString().trimRight();
  }

  static String _severityLabel(FrameSample f) {
    return switch (f.severity) {
      JankSeverity.healthy => 'OK',
      JankSeverity.minor => 'JANK',
      JankSeverity.major => 'MAJOR',
      JankSeverity.severe => 'SEVERE',
    };
  }

  static String _rebuildHeatmap(List<RegionStats> regions) {
    final sorted = [...regions]
      ..sort((a, b) => b.rebuilds.compareTo(a.rebuilds));
    final buf = StringBuffer()
      ..writeln(
        'REGION                    REBUILDS   /FRAME   PEAK',
      );
    for (final r in sorted) {
      buf.writeln(
        '${r.name.padRight(24)} '
        '${r.rebuilds.toString().padLeft(8)}  '
        '${r.averageRebuildsPerFrame.toStringAsFixed(2).padLeft(6)}  '
        '${r.peakRebuildsInFrame.toString().padLeft(5)}',
      );
    }
    return buf.toString().trimRight();
  }
}
