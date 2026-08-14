/// Keeps [lib/src/core/version.dart] in sync with pubspec.yaml.
///
/// Run:
///   dart run tool/sync_version.dart
///   dart run tool/sync_version.dart --check
library;

import 'dart:io';

void main(List<String> args) {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match =
      RegExp(r'^version:\s*([^\s+#]+)', multiLine: true).firstMatch(pubspec);
  if (match == null) {
    stderr.writeln('Could not find version: in pubspec.yaml');
    exit(1);
  }
  final version = match.group(1)!;
  final target = File('lib/src/core/version.dart');
  final expected = '/// Package version constant (Dart-only for CLI tooling).\n'
      '///\n'
      '/// Synced from pubspec.yaml via `dart run tool/sync_version.dart`.\n'
      "const String frameGuardPackageVersion = '$version';\n";

  final checkOnly = args.contains('--check');
  if (checkOnly) {
    if (!target.existsSync()) {
      stderr.writeln('Missing ${target.path}');
      exit(1);
    }
    final current = target.readAsStringSync().replaceAll('\r\n', '\n');
    if (current != expected) {
      stderr.writeln(
        'version.dart is out of sync with pubspec.yaml ($version).\n'
        'Run: dart run tool/sync_version.dart',
      );
      exit(1);
    }
    stdout.writeln('OK frameGuardPackageVersion = $version');
    return;
  }

  target.writeAsStringSync(expected);
  stdout.writeln('Synced frameGuardPackageVersion = $version');
}
