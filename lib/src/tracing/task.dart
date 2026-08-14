import 'package:meta/meta.dart';

/// Result of measuring a synchronous or async task on the UI isolate.
@immutable
class TaskMeasurement {
  /// Creates a measurement.
  const TaskMeasurement({
    required this.id,
    required this.name,
    required this.duration,
    required this.startedAt,
    required this.endedAt,
    required this.overlappingSlowFrames,
    required this.exceededBudget,
    this.budget,
  });

  /// Stable ID.
  final String id;

  /// Task name.
  final String name;

  /// Wall duration of the measured body.
  final Duration duration;

  /// Start time.
  final DateTime startedAt;

  /// End time.
  final DateTime endedAt;

  /// How many janky frames overlapped this task window.
  final int overlappingSlowFrames;

  /// Whether [duration] exceeded the configured UI-thread budget.
  final bool exceededBudget;

  /// Budget used for the check, if any.
  final Duration? budget;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'durationMs': duration.inMicroseconds / 1000.0,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'overlappingSlowFrames': overlappingSlowFrames,
        'exceededBudget': exceededBudget,
        if (budget != null) 'budgetMs': budget!.inMicroseconds / 1000.0,
      };

  /// Text block.
  String summary() {
    final buf = StringBuffer()
      ..writeln('TASK')
      ..writeln(name)
      ..writeln('Duration:')
      ..writeln('${(duration.inMicroseconds / 1000.0).toStringAsFixed(1)} ms')
      ..writeln('Overlap:')
      ..writeln('$overlappingSlowFrames slow frames');
    if (exceededBudget) {
      buf.writeln('Warning:');
      buf.writeln(
        'Synchronous work exceeded the configured UI-thread budget.',
      );
    }
    return buf.toString().trimRight();
  }
}
