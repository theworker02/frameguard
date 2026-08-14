import 'package:meta/meta.dart';

/// A reusable named performance scenario for repeated, comparable runs.
@immutable
class FrameScenario {
  /// Creates a scenario definition.
  const FrameScenario({
    required this.name,
    this.warmup = Duration.zero,
    this.warmupFrames = 0,
    this.duration,
    this.description,
    this.tags = const [],
  });

  /// Scenario name (used in reports and baselines).
  final String name;

  /// Wall-clock warmup before measurement.
  final Duration warmup;

  /// Warmup frames to discard before metrics.
  final int warmupFrames;

  /// Optional fixed measurement window.
  final Duration? duration;

  /// Optional human description.
  final String? description;

  /// Free-form tags for filtering.
  final List<String> tags;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'name': name,
        'warmupMs': warmup.inMilliseconds,
        'warmupFrames': warmupFrames,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
        if (description != null) 'description': description,
        if (tags.isNotEmpty) 'tags': tags,
      };
}
