import 'dart:io';

import 'package:frameguard/src/core/version.dart';
import 'package:frameguard/src/reporting/baseline.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Local environment health checks for FrameGuard setup.
///
/// Never phones home. Safe for CI and developer machines.
class FrameGuardDoctor {
  /// Creates a doctor for [workingDirectory] (defaults to cwd).
  FrameGuardDoctor({String? workingDirectory})
      : workingDirectory = workingDirectory ?? Directory.current.path;

  /// Directory to inspect.
  final String workingDirectory;

  /// Runs all checks.
  FrameGuardDoctorReport run() {
    final checks = <DoctorCheck>[
      _checkPackageVersion(),
      _checkSchemas(),
      _checkConfig(),
      _checkExampleConfig(),
      _checkReportsDir(),
      _checkBaselinesDir(),
      _checkDartSdk(),
    ];
    return FrameGuardDoctorReport(checks: checks);
  }

  DoctorCheck _checkPackageVersion() => const DoctorCheck(
        name: 'frameguard_version',
        passed: true,
        detail: 'Package $frameGuardPackageVersion',
      );

  DoctorCheck _checkSchemas() => const DoctorCheck(
        name: 'schemas',
        passed: true,
        detail: 'Report schema ${FrameGuardReport.currentSchemaVersion}, '
            'baseline schema ${FrameGuardBaseline.currentSchemaVersion}',
      );

  DoctorCheck _checkConfig() {
    final file =
        File('$workingDirectory${Platform.pathSeparator}frameguard.yaml');
    if (file.existsSync()) {
      return const DoctorCheck(
        name: 'config',
        passed: true,
        detail: 'Found frameguard.yaml',
      );
    }
    return const DoctorCheck(
      name: 'config',
      passed: true,
      warning: true,
      detail: 'No frameguard.yaml (optional — Dart config via '
          'FrameGuard.initialize is primary)',
    );
  }

  DoctorCheck _checkExampleConfig() {
    final file = File(
      '$workingDirectory${Platform.pathSeparator}frameguard.yaml.example',
    );
    if (file.existsSync()) {
      return const DoctorCheck(
        name: 'config_example',
        passed: true,
        detail: 'frameguard.yaml.example present',
      );
    }
    return const DoctorCheck(
      name: 'config_example',
      passed: true,
      warning: true,
      detail: 'No frameguard.yaml.example in working directory',
    );
  }

  DoctorCheck _checkReportsDir() {
    final dir = Directory('$workingDirectory${Platform.pathSeparator}reports');
    if (!dir.existsSync()) {
      return const DoctorCheck(
        name: 'reports_dir',
        passed: true,
        warning: true,
        detail: 'No reports/ directory yet (created when you write reports)',
      );
    }
    final count = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .length;
    return DoctorCheck(
      name: 'reports_dir',
      passed: true,
      detail: 'reports/ has $count JSON file(s)',
    );
  }

  DoctorCheck _checkBaselinesDir() {
    final dir =
        Directory('$workingDirectory${Platform.pathSeparator}baselines');
    if (!dir.existsSync()) {
      return const DoctorCheck(
        name: 'baselines_dir',
        passed: true,
        warning: true,
        detail: 'No baselines/ directory yet',
      );
    }
    final count = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .length;
    return DoctorCheck(
      name: 'baselines_dir',
      passed: true,
      detail: 'baselines/ has $count JSON file(s)',
    );
  }

  DoctorCheck _checkDartSdk() {
    return DoctorCheck(
      name: 'dart_sdk',
      passed: true,
      detail: 'Dart ${Platform.version.split(' ').first}',
    );
  }
}

/// One doctor check result.
class DoctorCheck {
  /// Creates a check result.
  const DoctorCheck({
    required this.name,
    required this.passed,
    required this.detail,
    this.warning = false,
  });

  /// Machine-readable name.
  final String name;

  /// Whether the check passed (hard failure).
  final bool passed;

  /// Soft warning (setup incomplete but OK).
  final bool warning;

  /// Human detail.
  final String detail;
}

/// Aggregate doctor report.
class FrameGuardDoctorReport {
  /// Creates a report.
  const FrameGuardDoctorReport({required this.checks});

  /// Individual checks.
  final List<DoctorCheck> checks;

  /// True when every check passed (warnings allowed).
  bool get ok => checks.every((c) => c.passed);

  /// Number of warnings.
  int get warningCount => checks.where((c) => c.warning).length;

  /// Text summary for CLI.
  String summary() {
    final buf = StringBuffer()
      ..writeln('FrameGuard doctor')
      ..writeln('─────────────────');
    for (final c in checks) {
      final mark = !c.passed
          ? '[FAIL]'
          : c.warning
              ? '[WARN]'
              : '[ OK ]';
      buf.writeln('$mark ${c.name}: ${c.detail}');
    }
    buf
      ..writeln()
      ..writeln(
        ok
            ? 'Ready ($warningCount warning(s)).'
            : 'Issues found — fix FAIL checks before CI gates.',
      );
    return buf.toString();
  }
}
