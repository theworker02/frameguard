import 'package:meta/meta.dart';

/// A custom diagnostic event emitted during a session.
@immutable
class FrameGuardMarker {
  /// Creates a marker.
  const FrameGuardMarker({
    required this.id,
    required this.name,
    required this.timestamp,
    this.metadata = const {},
    this.traceId,
  });

  /// Stable unique ID for correlation.
  final String id;

  /// Event name (e.g. `products_loaded`).
  final String name;

  /// When the marker was recorded.
  final DateTime timestamp;

  /// Optional structured metadata.
  final Map<String, Object?> metadata;

  /// Parent trace ID when nested inside a trace.
  final String? traceId;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'timestamp': timestamp.toIso8601String(),
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (traceId != null) 'traceId': traceId,
      };
}
