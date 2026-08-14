import 'dart:convert';

import 'package:frameguard/src/reporting/comparison.dart';
import 'package:frameguard/src/reporting/html_report.dart';
import 'package:frameguard/src/reporting/markdown_report.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Export format identifiers (extensible for future formats).
enum ReportExportFormat {
  /// Versioned FrameGuard JSON.
  json,

  /// Human-readable text.
  text,

  /// Static HTML.
  html,

  /// Markdown for PR comments / job summaries.
  markdown,

  /// CSV metrics table.
  csv,

  /// JUnit XML for CI test UIs.
  junit,

  /// SARIF (structured for code scanning — no fake source-line attribution).
  sarif,
}

/// Writes reports in machine formats used by CI systems.
class ReportExporter {
  /// Creates an exporter for [report].
  ReportExporter(this.report, {this.comparison});

  /// Source report.
  final FrameGuardReport report;

  /// Optional baseline comparison to include in JUnit/SARIF.
  final ComparisonResult? comparison;

  /// Renders [format].
  String export(ReportExportFormat format) {
    switch (format) {
      case ReportExportFormat.json:
        return report.toJsonString();
      case ReportExportFormat.text:
        return report.toText();
      case ReportExportFormat.html:
        return HtmlReportBuilder(report).build();
      case ReportExportFormat.markdown:
        return MarkdownReportBuilder(report, comparison: comparison).build();
      case ReportExportFormat.csv:
        return toCsv();
      case ReportExportFormat.junit:
        return toJUnit();
      case ReportExportFormat.sarif:
        return toSarif();
    }
  }

  /// CSV of key metrics + all frames.
  String toCsv() {
    final buf = StringBuffer()
      ..writeln('metric,value')
      ..writeln('scenario,${_csv(report.scenario)}')
      ..writeln('frames,${report.stats.totalFrames}')
      ..writeln('janky_frames,${report.stats.jankyFrames}')
      ..writeln('jank_rate,${report.stats.jankRate}')
      ..writeln('p50_ms,${_ms(report.stats.p50)}')
      ..writeln('p90_ms,${_ms(report.stats.p90)}')
      ..writeln('p95_ms,${_ms(report.stats.p95)}')
      ..writeln('p99_ms,${_ms(report.stats.p99)}')
      ..writeln('max_ms,${_ms(report.stats.max)}')
      ..writeln('avg_build_ms,${_ms(report.stats.averageBuild)}')
      ..writeln('avg_raster_ms,${_ms(report.stats.averageRaster)}')
      ..writeln('passed,${report.passed}')
      ..writeln()
      ..writeln('frame,total_ms,build_ms,raster_ms,severity,bottleneck');
    for (final f in report.frames) {
      buf.writeln(
        '${f.frameNumber},${_ms(f.totalDuration)},${_ms(f.buildDuration)},'
        '${_ms(f.rasterDuration)},${f.severity.name},${f.bottleneck.name}',
      );
    }
    return buf.toString();
  }

  /// JUnit XML so CI can display performance failures as test results.
  String toJUnit() {
    final passed = report.passed && !(comparison?.isRegression ?? false);
    final name = report.scenario;
    final failures = <String>[];
    if (report.budgetEvaluation != null && !report.budgetEvaluation!.passed) {
      for (final f in report.budgetEvaluation!.failures) {
        failures.add(f.message);
      }
    }
    if (comparison?.isRegression ?? false) {
      failures.add(comparison!.summary());
    }
    final failureXml = failures.isEmpty
        ? ''
        : '<failure message="${_xml(failures.first)}">'
            '${_xml(failures.join('\n'))}'
            '</failure>';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="FrameGuard" tests="1" failures="${passed ? 0 : 1}" errors="0">
  <testcase classname="frameguard.performance" name="${_xml(name)}" time="${report.duration.inMilliseconds / 1000.0}">
    $failureXml
    <system-out>${_xml(report.summary())}</system-out>
  </testcase>
</testsuite>
''';
  }

  /// SARIF 2.1.0 document for performance findings (scenario-level locations).
  String toSarif() {
    final results = <Map<String, Object?>>[];
    final diagnostics = report.explanation?.diagnostics ?? const [];
    for (final d in diagnostics) {
      results.add({
        'ruleId': d.id,
        'level': 'warning',
        'message': {
          'text':
              '${d.id} ${d.code}: ${report.explanation?.primaryFinding ?? d.code}',
        },
        'properties': {
          'scenario': report.scenario,
          'frameguardVersion': report.frameguardVersion,
        },
      });
    }
    if (comparison?.isRegression ?? false) {
      results.add({
        'ruleId': 'FG006',
        'level': 'error',
        'message': {'text': comparison!.summary()},
      });
    }
    if (!report.passed) {
      results.add({
        'ruleId': 'FG-BUDGET',
        'level': 'error',
        'message': {
          'text': report.budgetEvaluation?.summary() ?? 'Budget failed',
        },
      });
    }

    final doc = <String, Object?>{
      r'$schema':
          'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json',
      'version': '2.1.0',
      'runs': [
        {
          'tool': {
            'driver': {
              'name': 'FrameGuard',
              'version': report.frameguardVersion,
              'informationUri': 'https://github.com/theworker02/frameguard',
              'rules': [
                for (final d in diagnostics)
                  {
                    'id': d.id,
                    'name': d.code,
                    'shortDescription': {'text': d.code},
                  },
              ],
            },
          },
          'results': results,
        },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  static String _ms(Duration d) =>
      (d.inMicroseconds / 1000.0).toStringAsFixed(3);

  static String _csv(String s) => '"${s.replaceAll('"', '""')}"';

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
