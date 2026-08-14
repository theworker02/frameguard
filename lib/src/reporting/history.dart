import 'dart:convert';
import 'dart:io';

import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/reporting/drift.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:path/path.dart' as p;

/// One compact history point for local trend tracking (JSONL).
class HistoryEntry {
  /// Creates a history entry.
  const HistoryEntry({
    required this.recordedAt,
    required this.scenario,
    required this.reportId,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.maxMs,
    required this.jankRate,
    required this.totalFrames,
    required this.passed,
    this.sourcePath,
    this.frameguardVersion,
  });

  /// Wall-clock time this entry was recorded.
  final DateTime recordedAt;

  /// Scenario name.
  final String scenario;

  /// Report id.
  final String reportId;

  /// p50 total frame time (ms).
  final double p50Ms;

  /// p95 total frame time (ms).
  final double p95Ms;

  /// p99 total frame time (ms).
  final double p99Ms;

  /// Max total frame time (ms).
  final double maxMs;

  /// Jank rate 0–1.
  final double jankRate;

  /// Frame count.
  final int totalFrames;

  /// Whether the report passed its budget (when known).
  final bool? passed;

  /// Optional path to the source report.
  final String? sourcePath;

  /// Package version that produced the report.
  final String? frameguardVersion;

  /// Builds an entry from a full [report].
  factory HistoryEntry.fromReport(
    FrameGuardReport report, {
    String? sourcePath,
    DateTime? recordedAt,
  }) {
    double ms(Duration d) => d.inMicroseconds / 1000.0;
    return HistoryEntry(
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
      scenario: report.scenario,
      reportId: report.id,
      p50Ms: ms(report.stats.p50),
      p95Ms: ms(report.stats.p95),
      p99Ms: ms(report.stats.p99),
      maxMs: ms(report.stats.max),
      jankRate: report.stats.jankRate,
      totalFrames: report.stats.totalFrames,
      passed: report.passed,
      sourcePath: sourcePath,
      frameguardVersion: report.frameguardVersion,
    );
  }

  /// JSON map (one JSONL line).
  Map<String, Object?> toJson() => {
        'recordedAt': recordedAt.toIso8601String(),
        'scenario': scenario,
        'reportId': reportId,
        'p50Ms': p50Ms,
        'p95Ms': p95Ms,
        'p99Ms': p99Ms,
        'maxMs': maxMs,
        'jankRate': jankRate,
        'totalFrames': totalFrames,
        'passed': passed,
        if (sourcePath != null) 'sourcePath': sourcePath,
        if (frameguardVersion != null) 'frameguardVersion': frameguardVersion,
      };

  /// Restores from JSON.
  factory HistoryEntry.fromJson(Map<String, Object?> json) {
    return HistoryEntry(
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      scenario: json['scenario'] as String? ?? 'unknown',
      reportId: json['reportId'] as String? ?? '',
      p50Ms: (json['p50Ms'] as num?)?.toDouble() ?? 0,
      p95Ms: (json['p95Ms'] as num?)?.toDouble() ?? 0,
      p99Ms: (json['p99Ms'] as num?)?.toDouble() ?? 0,
      maxMs: (json['maxMs'] as num?)?.toDouble() ?? 0,
      jankRate: (json['jankRate'] as num?)?.toDouble() ?? 0,
      totalFrames: (json['totalFrames'] as num?)?.toInt() ?? 0,
      passed: json['passed'] as bool?,
      sourcePath: json['sourcePath'] as String?,
      frameguardVersion: json['frameguardVersion'] as String?,
    );
  }
}

/// Append-only local history store (`history/<scenario>.jsonl`).
///
/// Completely offline — no network, no telemetry.
class FrameGuardHistory {
  /// Creates a history store rooted at [directory].
  FrameGuardHistory({String? directory})
      : directory = directory ?? p.join(Directory.current.path, 'history');

  /// History directory (created on demand).
  final String directory;

  File _fileFor(String scenario) {
    final safe = scenario.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return File(p.join(directory, '$safe.jsonl'));
  }

  /// Appends [entry] for its scenario.
  Future<File> append(HistoryEntry entry) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = _fileFor(entry.scenario);
    await file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
    );
    return file;
  }

  /// Appends a compact entry derived from [report].
  Future<File> appendReport(
    FrameGuardReport report, {
    String? sourcePath,
  }) {
    return append(
      HistoryEntry.fromReport(report, sourcePath: sourcePath),
    );
  }

  /// Loads all entries for [scenario] (oldest → newest).
  Future<List<HistoryEntry>> load(String scenario) async {
    final file = _fileFor(scenario);
    if (!file.existsSync()) return const [];
    final lines = await file.readAsLines();
    final out = <HistoryEntry>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final map = jsonDecode(trimmed);
        if (map is Map) {
          out.add(HistoryEntry.fromJson(Map<String, Object?>.from(map)));
        }
      } on FormatException {
        // Skip corrupt lines rather than failing the whole log.
      }
    }
    return out;
  }

  /// Lists scenario files present in the history directory.
  List<String> listScenarios() {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jsonl'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList()
      ..sort();
  }

  /// Clears history for one scenario, or all when [scenario] is null.
  Future<int> clear({String? scenario}) async {
    if (scenario != null) {
      final file = _fileFor(scenario);
      if (file.existsSync()) {
        await file.delete();
        return 1;
      }
      return 0;
    }
    var n = 0;
    final dir = Directory(directory);
    if (!dir.existsSync()) return 0;
    for (final f in dir.listSync().whereType<File>()) {
      if (f.path.endsWith('.jsonl')) {
        await f.delete();
        n++;
      }
    }
    return n;
  }

  /// p95 drift across history entries for [scenario].
  Future<BaselineDrift> p95Drift(
    String scenario, {
    double gradualThreshold = 0.20,
  }) async {
    final entries = await load(scenario);
    if (entries.length < 2) {
      return BaselineDrift(
        metric: 'p95Ms',
        points: [
          for (final e in entries)
            DriftPoint(
              label: e.recordedAt.toIso8601String(),
              value: e.p95Ms,
            ),
        ],
        totalRelativeChange: 0,
        gradualRegression: false,
      );
    }
    final points = [
      for (final e in entries)
        DriftPoint(
          label: e.recordedAt.toIso8601String(),
          value: e.p95Ms,
        ),
    ];
    final first = points.first.value;
    final last = points.last.value;
    final rel = first == 0 ? 0.0 : (last - first) / first;
    var nonDecreasing = true;
    for (var i = 1; i < points.length; i++) {
      if (points[i].value + 0.05 < points[i - 1].value) {
        nonDecreasing = false;
        break;
      }
    }
    return BaselineDrift(
      metric: 'p95Ms',
      points: points,
      totalRelativeChange: rel,
      gradualRegression: nonDecreasing && rel >= gradualThreshold,
    );
  }

  /// Ensures the history directory exists.
  Future<void> ensureDirectory() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  /// Throws when [scenario] has no history.
  Future<List<HistoryEntry>> requireLoad(String scenario) async {
    final entries = await load(scenario);
    if (entries.isEmpty) {
      throw FrameGuardException(
        'No history for scenario "$scenario" under $directory',
      );
    }
    return entries;
  }
}
