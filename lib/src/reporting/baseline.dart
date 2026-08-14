import 'dart:convert';
import 'dart:io';

import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/environment/device_metadata.dart';
import 'package:frameguard/src/reporting/report.dart';

/// Versioned baseline DTO for regression comparison.
///
/// Deliberately separate from full report serialization.
class FrameGuardBaseline {
  /// Current baseline schema version.
  static const int currentSchemaVersion = 1;

  /// Creates a baseline.
  const FrameGuardBaseline({
    required this.schemaVersion,
    required this.scenario,
    required this.device,
    required this.metrics,
    this.customMetrics = const {},
    this.createdAt,
    this.sourceReportId,
  });

  /// Schema version.
  final int schemaVersion;

  /// Scenario name.
  final String scenario;

  /// Device metadata subset.
  final DeviceMetadata device;

  /// Core comparable metrics.
  final BaselineMetrics metrics;

  /// Custom metrics carried into comparisons.
  final Map<String, num> customMetrics;

  /// Creation time.
  final DateTime? createdAt;

  /// Source report ID when derived from a report.
  final String? sourceReportId;

  /// Builds a baseline from a completed report.
  factory FrameGuardBaseline.fromReport(FrameGuardReport report) {
    return FrameGuardBaseline(
      schemaVersion: currentSchemaVersion,
      scenario: report.scenario,
      device: report.device,
      metrics: BaselineMetrics(
        p50FrameMs: report.stats.p50.inMicroseconds / 1000.0,
        p95FrameMs: report.stats.p95.inMicroseconds / 1000.0,
        p99FrameMs: report.stats.p99.inMicroseconds / 1000.0,
        maxFrameMs: report.stats.max.inMicroseconds / 1000.0,
        jankRate: report.stats.jankRate,
        jankyFrames: report.stats.jankyFrames,
        averageBuildMs: report.stats.averageBuild.inMicroseconds / 1000.0,
        averageRasterMs: report.stats.averageRaster.inMicroseconds / 1000.0,
      ),
      customMetrics: report.customMetrics,
      createdAt: DateTime.now(),
      sourceReportId: report.id,
    );
  }

  /// JSON DTO.
  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'scenario': scenario,
        'device': {
          'platform': device.platform,
          'refreshRateHz': device.refreshRateHz,
          if (device.flutterVersion != null)
            'flutterVersion': device.flutterVersion,
          'buildMode': device.buildMode.name,
        },
        'metrics': metrics.toJson(),
        if (customMetrics.isNotEmpty) 'customMetrics': customMetrics,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (sourceReportId != null) 'sourceReportId': sourceReportId,
      };

  /// Parses baseline JSON.
  factory FrameGuardBaseline.fromJson(Map<String, Object?> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version != currentSchemaVersion) {
      throw InvalidBaselineException(
        'Unable to read FrameGuard baseline.\n'
        'Expected schema version: $currentSchemaVersion\n'
        'Found: $version',
      );
    }
    final deviceMap = Map<String, Object?>.from(json['device'] as Map? ?? {});
    final metricsMap = Map<String, Object?>.from(json['metrics'] as Map? ?? {});
    return FrameGuardBaseline(
      schemaVersion: version,
      scenario: json['scenario'] as String? ?? 'unknown',
      device: DeviceMetadata.fromJson(deviceMap),
      metrics: BaselineMetrics.fromJson(metricsMap),
      customMetrics: Map<String, num>.from(
        (json['customMetrics'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v as num),
            ) ??
            const {},
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      sourceReportId: json['sourceReportId'] as String?,
    );
  }

  /// Writes JSON to [file]. Never called implicitly — baselines require
  /// deliberate update actions.
  Future<void> write(File file) async {
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }

  /// Loads from [file].
  static Future<FrameGuardBaseline> load(File file) async {
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw InvalidBaselineException(
        'Unable to read FrameGuard baseline.\n'
        'Expected a JSON object in ${file.path}',
      );
    }
    return FrameGuardBaseline.fromJson(Map<String, Object?>.from(decoded));
  }
}

/// Core metrics stored in a baseline.
class BaselineMetrics {
  /// Creates metrics.
  const BaselineMetrics({
    required this.p50FrameMs,
    required this.p95FrameMs,
    required this.p99FrameMs,
    required this.maxFrameMs,
    required this.jankRate,
    required this.jankyFrames,
    required this.averageBuildMs,
    required this.averageRasterMs,
  });

  /// p50 frame time in ms.
  final double p50FrameMs;

  /// p95 frame time in ms.
  final double p95FrameMs;

  /// p99 frame time in ms.
  final double p99FrameMs;

  /// Worst frame in ms.
  final double maxFrameMs;

  /// Jank rate 0–1.
  final double jankRate;

  /// Absolute janky frame count.
  final int jankyFrames;

  /// Average build ms.
  final double averageBuildMs;

  /// Average raster ms.
  final double averageRasterMs;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'p50FrameMs': p50FrameMs,
        'p95FrameMs': p95FrameMs,
        'p99FrameMs': p99FrameMs,
        'maxFrameMs': maxFrameMs,
        'jankRate': jankRate,
        'jankyFrames': jankyFrames,
        'averageBuildMs': averageBuildMs,
        'averageRasterMs': averageRasterMs,
      };

  /// Parses from JSON.
  factory BaselineMetrics.fromJson(Map<String, Object?> json) {
    return BaselineMetrics(
      p50FrameMs: (json['p50FrameMs'] as num?)?.toDouble() ?? 0,
      p95FrameMs: (json['p95FrameMs'] as num?)?.toDouble() ?? 0,
      p99FrameMs: (json['p99FrameMs'] as num?)?.toDouble() ?? 0,
      maxFrameMs: (json['maxFrameMs'] as num?)?.toDouble() ?? 0,
      jankRate: (json['jankRate'] as num?)?.toDouble() ?? 0,
      jankyFrames: (json['jankyFrames'] as num?)?.toInt() ?? 0,
      averageBuildMs: (json['averageBuildMs'] as num?)?.toDouble() ?? 0,
      averageRasterMs: (json['averageRasterMs'] as num?)?.toDouble() ?? 0,
    );
  }
}
