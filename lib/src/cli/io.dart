import 'dart:convert';
import 'dart:io';

import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/reporting/baseline.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:path/path.dart' as p;

/// Shared filesystem helpers for the FrameGuard CLI.
abstract final class CliIo {
  /// Loads a single report JSON file.
  static Future<FrameGuardReport> loadReport(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw FrameGuardException(
        'Unable to read FrameGuard report.\n'
        'File not found: $path',
      );
    }
    try {
      return await FrameGuardReport.load(file);
    } on UnsupportedSchemaException {
      rethrow;
    } catch (e) {
      throw FrameGuardException(
        'Unable to read FrameGuard report.\n'
        'Path: $path\n'
        'Detail: $e\n'
        'Expected schema version: ${FrameGuardReport.currentSchemaVersion}',
      );
    }
  }

  /// Loads a baseline JSON file.
  static Future<FrameGuardBaseline> loadBaseline(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw FrameGuardException('Baseline not found: $path');
    }
    return FrameGuardBaseline.load(file);
  }

  /// Collects report JSON files from a path or directory.
  static Future<List<({String path, FrameGuardReport report})>> loadReports(
    String target, {
    bool recursive = false,
  }) async {
    final entity = FileSystemEntity.typeSync(target);
    final files = <File>[];
    if (entity == FileSystemEntityType.directory) {
      final stream = recursive
          ? Directory(target).list(recursive: true)
          : Directory(target).list();
      await for (final e in stream) {
        if (e is File && e.path.toLowerCase().endsWith('.json')) {
          files.add(e);
        }
      }
      files.sort((a, b) => a.path.compareTo(b.path));
    } else if (entity == FileSystemEntityType.file) {
      files.add(File(target));
    } else {
      throw FrameGuardException('No file or directory at $target');
    }

    final out = <({String path, FrameGuardReport report})>[];
    for (final f in files) {
      // Skip baseline-shaped JSON (has metrics + no frames list).
      try {
        final raw = jsonDecode(await f.readAsString());
        if (raw is Map &&
            raw.containsKey('metrics') &&
            !raw.containsKey('frames')) {
          continue;
        }
      } catch (_) {
        continue;
      }
      out.add((path: f.path, report: await loadReport(f.path)));
    }
    return out;
  }

  /// Lists JSON files in [dir] (non-recursive).
  static List<File> listJsonFiles(String dir) {
    final d = Directory(dir);
    if (!d.existsSync()) return const [];
    return d
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Writes [text] to [out] or stdout.
  static Future<void> writeOut(
    String text, {
    String? out,
    required bool quiet,
    String? wroteLabel,
  }) async {
    if (out != null) {
      final file = File(out);
      await file.parent.create(recursive: true);
      await file.writeAsString(text);
      if (!quiet) {
        stdout.writeln(wroteLabel ?? 'Wrote: $out');
      }
    } else {
      stdout.writeln(text);
    }
  }

  /// Pretty path relative to cwd when possible.
  static String rel(String path) {
    final cwd = Directory.current.path;
    final n = p.normalize(path);
    if (p.isWithin(cwd, n)) return p.relative(n, from: cwd);
    return n;
  }

  static String ms(Duration d) =>
      (d.inMicroseconds / 1000.0).toStringAsFixed(1);

  static String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}
