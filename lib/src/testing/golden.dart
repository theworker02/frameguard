import 'dart:convert';
import 'dart:io';

import 'package:frameguard/src/reporting/baseline.dart';
import 'package:frameguard/src/reporting/comparison.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:path/path.dart' as p;

/// Golden performance baseline helpers for tests.
///
/// Never silently overwrites baselines — updates require deliberate CLI/action.
class FrameGuardGolden {
  /// Default directory for golden baselines relative to the package root.
  static const String defaultDirectory = 'baselines';

  /// Expects [report] to match the golden baseline named [name].
  ///
  /// If the baseline is missing, throws with instructions to generate it.
  static Future<void> expectMatches(
    FrameGuardReport report,
    String name, {
    String directory = defaultDirectory,
    ComparisonThresholds thresholds = const ComparisonThresholds(),
    bool requireMatchingEnvironment = false,
  }) async {
    final file = File(p.join(directory, '$name.json'));
    if (!file.existsSync()) {
      throw StateError(
        'Missing baseline.\n'
        'Generate from a known-good report with:\n'
        '  dart run frameguard baseline update <report.json> --out ${file.path}\n'
        'Or call FrameGuardGolden.update(report, \'$name\', overwrite: true).',
      );
    }
    final baseline = await FrameGuardBaseline.load(file);
    final result = FrameGuardCompare(
      thresholds: thresholds,
      requireMatchingEnvironment: requireMatchingEnvironment,
    ).compareReportToBaseline(report, baseline);
    if (result.isRegression) {
      throw TestFailure(result.summary());
    }
  }

  /// Writes a baseline for [report] only when [overwrite] is true.
  ///
  /// Refuses to clobber an existing file unless [overwrite] is set.
  static Future<File> update(
    FrameGuardReport report,
    String name, {
    String directory = defaultDirectory,
    bool overwrite = false,
  }) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(directory, '$name.json'));
    if (file.existsSync() && !overwrite) {
      throw StateError(
        'Baseline already exists: ${file.path}\n'
        'Refusing to overwrite. Pass overwrite: true or use:\n'
        '  dart run frameguard baseline update <report.json> --out ${file.path} --force',
      );
    }
    final baseline = FrameGuardBaseline.fromReport(report);
    await baseline.write(file);
    return file;
  }
}

/// Minimal TestFailure without importing flutter_test in all paths.
class TestFailure implements Exception {
  /// Creates a failure.
  TestFailure(this.message);

  /// Message.
  final String message;

  @override
  String toString() => 'TestFailure: $message';
}

/// Writes a report JSON beside baselines for review workflows.
Future<void> writeReportArtifact(
  FrameGuardReport report, {
  required String path,
}) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report.toJson()),
  );
}
