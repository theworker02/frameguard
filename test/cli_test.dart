import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final root = Directory.current.path;
  final dartBin = _resolveDartExecutable();
  final cli = p.join(root, 'bin', 'frameguard.dart');
  final fixtures = p.join(root, 'test', 'fixtures');

  Future<ProcessResult> runCli(List<String> args) {
    return Process.run(
      dartBin,
      [cli, ...args],
      workingDirectory: root,
    );
  }

  test('resolves a usable dart executable', () {
    expect(dartBin, isNot(contains('flutter_tester')));
    expect(File(dartBin).existsSync() || dartBin == 'dart', isTrue);
  });

  test('version prints 0.6.0', () async {
    final r = await runCli(['version']);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('0.6.0'));
  });

  test('doctor exits 0', () async {
    final r = await runCli(['doctor']);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('FrameGuard doctor'));
  });

  test('inspect healthy fixture', () async {
    final r = await runCli([
      'inspect',
      p.join(fixtures, 'healthy_scroll.json'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString().toLowerCase(), contains('healthy'));
  });

  test('check fails on catalog budget failure', () async {
    final r = await runCli([
      'check',
      p.join(fixtures, 'catalog_scroll.json'),
    ]);
    expect(r.exitCode, 1);
  });

  test('check passes healthy fixture', () async {
    final r = await runCli([
      'check',
      p.join(fixtures, 'healthy_scroll.json'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });

  test('export markdown contains FrameGuard heading', () async {
    final out = p.join(root, 'tmp_check', 'summary.md');
    await Directory(p.dirname(out)).create(recursive: true);
    final r = await runCli([
      'export',
      p.join(fixtures, 'catalog_scroll.json'),
      '--format',
      'markdown',
      '--out',
      out,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    final text = await File(out).readAsString();
    expect(text, contains('## FrameGuard'));
    expect(text, contains('catalog_scroll'));
  });

  test('summary one-liner', () async {
    final r = await runCli([
      'summary',
      p.join(fixtures, 'healthy_scroll.json'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('FrameGuard[healthy_scroll]'));
  });

  test('config validate example yaml', () async {
    final r = await runCli([
      'config',
      'validate',
      'frameguard.yaml.example',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('OK'));
  });

  test('compare detects regression vs worse run', () async {
    final r = await runCli([
      'compare',
      p.join(fixtures, 'healthy_scroll.json'),
      p.join(fixtures, 'healthy_scroll_worse.json'),
    ]);
    expect(r.exitCode, 1);
  });

  test('explain prints primary finding', () async {
    final r = await runCli([
      'explain',
      p.join(fixtures, 'catalog_scroll.json'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('PRIMARY'));
  });

  test('frames lists slow frames', () async {
    final r = await runCli([
      'frames',
      p.join(fixtures, 'catalog_scroll.json'),
      '--limit',
      '5',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('TOTAL'));
  });

  test('profiles lists builtins', () async {
    final r = await runCli(['profiles']);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('mid_range'));
  });

  test('validate fixture ok', () async {
    final r = await runCli([
      'validate',
      p.join(fixtures, 'healthy_scroll.json'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('OK'));
  });

  test('help lists commands', () async {
    final r = await runCli(['help']);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('watch'));
    expect(r.stdout.toString(), contains('explain'));
  });

  test('completions bash', () async {
    final r = await runCli(['completions', '--shell', 'bash']);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('complete'));
  });

  test('top prints sections', () async {
    final r = await runCli([
      'top',
      p.join(fixtures, 'catalog_scroll.json'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('Top frames'));
  });

  test('histogram prints buckets', () async {
    final r = await runCli([
      'histogram',
      p.join(fixtures, 'healthy_scroll.json'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString().toLowerCase(), contains('ms'));
  });

  test('check with profile mid_range', () async {
    final r = await runCli([
      'check',
      p.join(fixtures, 'healthy_scroll.json'),
      '--profile',
      'low_end',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
  });

  test('require-profile without profile fails', () async {
    final r = await runCli([
      'check',
      p.join(fixtures, 'healthy_scroll.json'),
      '--require-profile',
    ]);
    expect(r.exitCode, 2, reason: '${r.stderr}\n${r.stdout}');
  });

  test('suggest-budget emits dart snippet', () async {
    final r = await runCli([
      'suggest-budget',
      p.join(fixtures, 'healthy_scroll.json'),
      '--format',
      'dart',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('FrameBudget'));
  });

  test('help mentions history and suggest-budget', () async {
    final r = await runCli(['help']);
    expect(r.exitCode, 0, reason: '${r.stderr}\n${r.stdout}');
    expect(r.stdout.toString(), contains('history'));
    expect(r.stdout.toString(), contains('suggest-budget'));
  });
}

String _resolveDartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    if (Platform.isWindows) {
      final bat = p.join(flutterRoot, 'bin', 'dart.bat');
      if (File(bat).existsSync()) return bat;
      final exe = p.join(flutterRoot, 'bin', 'dart.exe');
      if (File(exe).existsSync()) return exe;
    } else {
      final dart = p.join(flutterRoot, 'bin', 'dart');
      if (File(dart).existsSync()) return dart;
    }
  }

  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      final bat = p.join(localAppData, 'flutter', 'bin', 'dart.bat');
      if (File(bat).existsSync()) return bat;
      final exe = p.join(localAppData, 'flutter', 'bin', 'dart.exe');
      if (File(exe).existsSync()) return exe;
    }
  }

  // Under `dart test` / some runners this is the dart VM; skip flutter_tester.
  final resolved = Platform.resolvedExecutable;
  if (!resolved.contains('flutter_tester')) {
    return resolved;
  }

  return 'dart';
}
