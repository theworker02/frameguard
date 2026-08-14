import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/diagnostics/explainability.dart';
import 'package:frameguard/src/environment/device_metadata.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/budget_evaluation.dart';
import 'package:frameguard/src/metrics/frame_sample.dart';
import 'package:frameguard/src/metrics/frame_stats.dart';
import 'package:frameguard/src/metrics/histogram.dart';
import 'package:frameguard/src/metrics/image_diagnostics.dart';
import 'package:frameguard/src/metrics/jank.dart';
import 'package:frameguard/src/metrics/region_stats.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:frameguard/src/tracing/marker.dart';
import 'package:frameguard/src/tracing/task.dart';
import 'package:frameguard/src/tracing/trace.dart';

/// Versioned DTO encode/decode for [FrameGuardReport].
///
/// Persistent format is intentionally decoupled from internal class layouts.
class JsonReportEncoder {
  JsonReportEncoder._();

  /// Encodes a report to a versioned JSON map.
  static Map<String, Object?> encode(FrameGuardReport report) {
    return {
      'schemaVersion': report.schemaVersion,
      'id': report.id,
      'scenario': report.scenario,
      'startedAt': report.startedAt.toIso8601String(),
      'endedAt': report.endedAt.toIso8601String(),
      'frameguardVersion': report.frameguardVersion,
      'device': report.device.toJson(),
      'frameBudgetTargetMs': report.frameBudgetTarget.inMicroseconds / 1000.0,
      'refreshRateHz': report.refreshRateHz,
      'refreshRateFallback': report.refreshRateFallback,
      'warmupFrameCount': report.warmupFrameCount,
      'stats': report.stats.toJson(),
      'frames': report.frames.map((f) => f.toJson()).toList(),
      'markers': report.markers.map((m) => m.toJson()).toList(),
      'traces': report.traces.map((t) => t.toJson()).toList(),
      'tasks': report.tasks.map((t) => t.toJson()).toList(),
      'regions': report.regions.map((r) => r.toJson()).toList(),
      'customMetrics': report.customMetrics,
      'imageWarnings': report.imageWarnings.map((i) => i.toJson()).toList(),
      if (report.imageCache != null) 'imageCache': report.imageCache!.toJson(),
      if (report.budget != null) 'budget': report.budget!.toJson(),
      if (report.budgetEvaluation != null)
        'budgetEvaluation': report.budgetEvaluation!.toJson(),
      if (report.explanation != null)
        'explanation': report.explanation!.toJson(),
      if (report.debugModeWarning != null)
        'debugModeWarning': report.debugModeWarning,
      'score': report.score.toJson(),
    };
  }

  /// Decodes a versioned JSON map.
  static FrameGuardReport decode(Map<String, Object?> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version != FrameGuardReport.currentSchemaVersion) {
      throw UnsupportedSchemaException(
        expected: FrameGuardReport.currentSchemaVersion,
        found: version,
      );
    }

    final deviceJson = Map<String, Object?>.from(
      json['device'] as Map? ?? const {},
    );
    final statsJson = Map<String, Object?>.from(
      json['stats'] as Map? ?? const {},
    );

    final frames = (json['frames'] as List? ?? const [])
        .map((e) => _frameFromJson(Map<String, Object?>.from(e as Map)))
        .toList();

    return FrameGuardReport(
      schemaVersion: version,
      id: json['id'] as String? ?? 'unknown',
      scenario: json['scenario'] as String? ?? 'unknown',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      frameguardVersion: json['frameguardVersion'] as String? ?? '0.0.0',
      device: DeviceMetadata.fromJson(deviceJson),
      frameBudgetTarget:
          _ms(json['frameBudgetTargetMs']) ?? const Duration(milliseconds: 16),
      refreshRateHz: (json['refreshRateHz'] as num?)?.toDouble() ?? 60,
      refreshRateFallback: json['refreshRateFallback'] as bool? ?? true,
      frames: frames,
      warmupFrameCount: (json['warmupFrameCount'] as num?)?.toInt() ?? 0,
      stats: _statsFromJson(statsJson, frames),
      markers: (json['markers'] as List? ?? const [])
          .map((e) => _markerFromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      traces: (json['traces'] as List? ?? const [])
          .map((e) => _traceFromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      tasks: (json['tasks'] as List? ?? const [])
          .map((e) => _taskFromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      regions: (json['regions'] as List? ?? const [])
          .map((e) => _regionFromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      customMetrics: Map<String, num>.from(
        (json['customMetrics'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v as num),
            ) ??
            const {},
      ),
      imageWarnings: (json['imageWarnings'] as List? ?? const [])
          .map((e) => _imageFromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      imageCache: json['imageCache'] is Map
          ? _cacheFromJson(
              Map<String, Object?>.from(json['imageCache']! as Map))
          : null,
      budget: json['budget'] is Map
          ? FrameBudget.fromJson(
              Map<String, Object?>.from(json['budget']! as Map))
          : null,
      budgetEvaluation: json['budgetEvaluation'] is Map
          ? _evalFromJson(
              Map<String, Object?>.from(json['budgetEvaluation']! as Map),
            )
          : null,
      explanation: json['explanation'] is Map
          ? ScenarioExplanation.fromJson(
              Map<String, Object?>.from(json['explanation']! as Map),
            )
          : null,
      debugModeWarning: json['debugModeWarning'] as String?,
    );
  }

  static Duration? _ms(Object? v) {
    if (v is num) return Duration(microseconds: (v * 1000).round());
    return null;
  }

  static FrameSample _frameFromJson(Map<String, Object?> json) {
    final severityName = json['severity'] as String? ?? 'healthy';
    final severity = JankSeverity.values.firstWhere(
      (s) => s.name == severityName,
      orElse: () => JankSeverity.healthy,
    );
    final bottleneckName =
        json['bottleneck'] as String? ?? 'insufficientEvidence';
    final bottleneck = FrameBottleneck.values.firstWhere(
      (b) => b.name == bottleneckName,
      orElse: () => FrameBottleneck.insufficientEvidence,
    );
    return FrameSample(
      frameNumber: (json['frameNumber'] as num?)?.toInt() ?? 0,
      buildDuration: _ms(json['buildMs']) ?? Duration.zero,
      rasterDuration: _ms(json['rasterMs']) ?? Duration.zero,
      totalDuration: _ms(json['totalMs']) ?? Duration.zero,
      vsyncOverhead: _ms(json['vsyncOverheadMs']) ?? Duration.zero,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      severity: severity,
      janky: json['janky'] as bool? ?? false,
      bottleneck: bottleneck,
      layerCount: (json['layerCount'] as num?)?.toInt(),
      eventIds: (json['eventIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  static FrameStats _statsFromJson(
    Map<String, Object?> json,
    List<FrameSample> frames,
  ) {
    // Prefer recomputing from frames when present for consistency.
    if (frames.isNotEmpty) return FrameStats.compute(frames);
    final dist = json['jankDistribution'] is Map
        ? JankDistribution(
            healthy: ((json['jankDistribution'] as Map)['healthy'] as num?)
                    ?.toInt() ??
                0,
            minor:
                ((json['jankDistribution'] as Map)['minor'] as num?)?.toInt() ??
                    0,
            major:
                ((json['jankDistribution'] as Map)['major'] as num?)?.toInt() ??
                    0,
            severe: ((json['jankDistribution'] as Map)['severe'] as num?)
                    ?.toInt() ??
                0,
          )
        : const JankDistribution();
    final hist = json['histogram'] is Map
        ? FrameHistogram(
            buckets: ((json['histogram'] as Map)['buckets'] as List?)
                    ?.cast<String>() ??
                const [],
            counts: ((json['histogram'] as Map)['counts'] as List?)
                    ?.map((e) => (e as num).toInt())
                    .toList() ??
                const [],
          )
        : const FrameHistogram(buckets: [], counts: []);
    return FrameStats(
      totalFrames: (json['totalFrames'] as num?)?.toInt() ?? 0,
      jankyFrames: (json['jankyFrames'] as num?)?.toInt() ?? 0,
      jankRate: (json['jankRate'] as num?)?.toDouble() ?? 0,
      average: _ms(json['averageMs']) ?? Duration.zero,
      median: _ms(json['medianMs']) ?? Duration.zero,
      p50: _ms(json['p50Ms']) ?? Duration.zero,
      p90: _ms(json['p90Ms']) ?? Duration.zero,
      p95: _ms(json['p95Ms']) ?? Duration.zero,
      p99: _ms(json['p99Ms']) ?? Duration.zero,
      max: _ms(json['maxMs']) ?? Duration.zero,
      averageBuild: _ms(json['averageBuildMs']) ?? Duration.zero,
      averageRaster: _ms(json['averageRasterMs']) ?? Duration.zero,
      buildBoundFrames: (json['buildBoundFrames'] as num?)?.toInt() ?? 0,
      rasterBoundFrames: (json['rasterBoundFrames'] as num?)?.toInt() ?? 0,
      mixedFrames: (json['mixedFrames'] as num?)?.toInt() ?? 0,
      insufficientEvidenceFrames:
          (json['insufficientEvidenceFrames'] as num?)?.toInt() ?? 0,
      longestJankStreak: (json['longestJankStreak'] as num?)?.toInt() ?? 0,
      jankDistribution: dist,
      histogram: hist,
      stdDev: _ms(json['stdDevMs']) ?? Duration.zero,
    );
  }

  static FrameGuardMarker _markerFromJson(Map<String, Object?> json) {
    return FrameGuardMarker(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
      traceId: json['traceId'] as String?,
    );
  }

  static FrameGuardTraceResult _traceFromJson(Map<String, Object?> json) {
    final started = DateTime.tryParse(json['startedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final ended =
        DateTime.tryParse(json['endedAt'] as String? ?? '') ?? started;
    return FrameGuardTraceResult(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      startedAt: started,
      endedAt: ended,
      duration: _ms(json['durationMs']) ?? ended.difference(started),
      parentId: json['parentId'] as String?,
      childIds: (json['childIds'] as List?)?.cast<String>() ?? const [],
      markerIds: (json['markerIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  static TaskMeasurement _taskFromJson(Map<String, Object?> json) {
    return TaskMeasurement(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      duration: _ms(json['durationMs']) ?? Duration.zero,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      overlappingSlowFrames:
          (json['overlappingSlowFrames'] as num?)?.toInt() ?? 0,
      exceededBudget: json['exceededBudget'] as bool? ?? false,
      budget: _ms(json['budgetMs']),
    );
  }

  static RegionStats _regionFromJson(Map<String, Object?> json) {
    return RegionStats(
      name: json['name'] as String? ?? '',
      rebuilds: (json['rebuilds'] as num?)?.toInt() ?? 0,
      framesObserved: (json['framesObserved'] as num?)?.toInt() ?? 0,
      averageRebuildsPerFrame:
          (json['averageRebuildsPerFrame'] as num?)?.toDouble() ?? 0,
      peakRebuildsInFrame: (json['peakRebuildsInFrame'] as num?)?.toInt() ?? 0,
      buildProxyTotal: _ms(json['buildProxyTotalMs']),
      parent: json['parent'] as String?,
    );
  }

  static ImageWarning _imageFromJson(Map<String, Object?> json) {
    return ImageWarning(
      description: json['description'] as String? ?? '',
      displayWidth: (json['displayWidth'] as num?)?.toDouble() ?? 0,
      displayHeight: (json['displayHeight'] as num?)?.toDouble() ?? 0,
      decodedWidth: (json['decodedWidth'] as num?)?.toInt() ?? 0,
      decodedHeight: (json['decodedHeight'] as num?)?.toInt() ?? 0,
      estimatedDecodedBytes:
          (json['estimatedDecodedBytes'] as num?)?.toInt() ?? 0,
    );
  }

  static ImageCacheSnapshot _cacheFromJson(Map<String, Object?> json) {
    return ImageCacheSnapshot(
      currentEntries: (json['currentEntries'] as num?)?.toInt() ?? 0,
      currentBytes: (json['currentBytes'] as num?)?.toInt() ?? 0,
      liveEntries: (json['liveEntries'] as num?)?.toInt() ?? 0,
      peakEntries: (json['peakEntries'] as num?)?.toInt() ?? 0,
      peakBytes: (json['peakBytes'] as num?)?.toInt() ?? 0,
      evictions: (json['evictions'] as num?)?.toInt() ?? 0,
    );
  }

  static BudgetEvaluation _evalFromJson(Map<String, Object?> json) {
    final checks = (json['checks'] as List? ?? const []).map((e) {
      final m = Map<String, Object?>.from(e as Map);
      return BudgetCheck(
        name: m['name'] as String? ?? '',
        passed: m['passed'] as bool? ?? false,
        actual: m['actual'] as String? ?? '',
        limit: m['limit'] as String? ?? '',
        message: m['message'] as String? ?? '',
      );
    }).toList();
    return BudgetEvaluation(
      passed: json['passed'] as bool? ?? false,
      checks: checks,
    );
  }
}
