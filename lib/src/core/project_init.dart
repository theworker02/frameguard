import 'dart:io';

/// Scaffolds local FrameGuard directories and an optional YAML config.
class FrameGuardInit {
  /// Creates an initializer for [workingDirectory].
  FrameGuardInit({String? workingDirectory})
      : workingDirectory = workingDirectory ?? Directory.current.path;

  /// Target directory.
  final String workingDirectory;

  /// Runs scaffolding. Returns human-readable actions taken.
  Future<List<String>> run({bool writeYaml = true}) async {
    final actions = <String>[];
    final sep = Platform.pathSeparator;

    for (final name in ['reports', 'baselines', 'history']) {
      final dir = Directory('$workingDirectory$sep$name');
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
        actions.add('created $name/');
      } else {
        actions.add('exists $name/');
      }
    }

    final example = File('$workingDirectory${sep}frameguard.yaml.example');
    final yaml = File('$workingDirectory${sep}frameguard.yaml');
    if (writeYaml && !yaml.existsSync()) {
      if (example.existsSync()) {
        await yaml.writeAsString(await example.readAsString());
        actions.add('wrote frameguard.yaml from example');
      } else {
        await yaml.writeAsString(_defaultYaml);
        actions.add('wrote frameguard.yaml');
      }
    } else if (yaml.existsSync()) {
      actions.add('exists frameguard.yaml');
    }

    return actions;
  }

  static const _defaultYaml = '''
# Optional project config (Dart config remains primary).
frameguard:
  refresh_rate: auto
  sampling_mode: balanced
  budgets:
    max_jank_rate: 0.01
    max_p95_ms: 16
    max_p99_ms: 24
  profiles:
    mid_range:
      max_jank_rate: 0.02
      max_p95_ms: 18
    strict:
      max_jank_rate: 0.005
      max_p95_ms: 8.5
''';
}
