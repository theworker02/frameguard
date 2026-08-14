import 'dart:async';
import 'dart:developer' as developer;

import 'package:frameguard/src/tracing/marker.dart';
import 'package:meta/meta.dart';

/// Called when a trace ends so FrameGuard can record it without a circular
/// import from this pure-Dart library into the Flutter runtime facade.
typedef TraceCompletedCallback = void Function(FrameGuardTrace trace);

/// Hook installed by [FrameGuard.initialize].
TraceCompletedCallback? onTraceCompleted;

/// An interaction trace capturing frames and events for a named operation.
class FrameGuardTrace {
  /// Creates a trace (prefer [FrameGuard.beginTrace] / [FrameGuard.trace]).
  FrameGuardTrace._({
    required this.id,
    required this.name,
    required this.startedAt,
    this.parentId,
  });

  /// Stable trace ID.
  final String id;

  /// Trace name.
  final String name;

  /// Start timestamp.
  final DateTime startedAt;

  /// Parent trace ID for nested traces.
  final String? parentId;

  DateTime? _endedAt;
  final List<String> _childIds = [];
  final List<String> _markerIds = [];

  /// Whether the trace is still open.
  bool get isOpen => _endedAt == null;

  /// End timestamp when closed.
  DateTime? get endedAt => _endedAt;

  /// Child trace IDs.
  List<String> get childIds => List.unmodifiable(_childIds);

  /// Marker IDs recorded under this trace.
  List<String> get markerIds => List.unmodifiable(_markerIds);

  /// Records a child trace relationship.
  void attachChild(String childId) => _childIds.add(childId);

  /// Records a marker under this trace.
  void attachMarker(String markerId) => _markerIds.add(markerId);

  /// Ends the trace and returns a snapshot.
  Future<FrameGuardTraceResult> end() async {
    if (_endedAt != null) {
      return FrameGuardTraceResult.fromTrace(this);
    }
    _endedAt = DateTime.now();
    developer.Timeline.finishSync();
    onTraceCompleted?.call(this);
    return FrameGuardTraceResult.fromTrace(this);
  }
}

/// Immutable result of a completed trace.
@immutable
class FrameGuardTraceResult {
  /// Creates a result.
  const FrameGuardTraceResult({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    this.parentId,
    this.childIds = const [],
    this.markerIds = const [],
  });

  /// Builds from an open or closed [FrameGuardTrace].
  factory FrameGuardTraceResult.fromTrace(FrameGuardTrace trace) {
    final ended = trace.endedAt ?? DateTime.now();
    return FrameGuardTraceResult(
      id: trace.id,
      name: trace.name,
      startedAt: trace.startedAt,
      endedAt: ended,
      duration: ended.difference(trace.startedAt),
      parentId: trace.parentId,
      childIds: trace.childIds,
      markerIds: trace.markerIds,
    );
  }

  /// Trace ID.
  final String id;

  /// Name.
  final String name;

  /// Start.
  final DateTime startedAt;

  /// End.
  final DateTime endedAt;

  /// Duration.
  final Duration duration;

  /// Parent ID.
  final String? parentId;

  /// Children.
  final List<String> childIds;

  /// Markers.
  final List<String> markerIds;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'durationMs': duration.inMicroseconds / 1000.0,
        if (parentId != null) 'parentId': parentId,
        if (childIds.isNotEmpty) 'childIds': childIds,
        if (markerIds.isNotEmpty) 'markerIds': markerIds,
      };
}

/// Factory helpers used by FrameGuard (library-private via public facade).
FrameGuardTrace createTrace({
  required String id,
  required String name,
  String? parentId,
}) {
  developer.Timeline.startSync('frameguard:$name', arguments: {'id': id});
  return FrameGuardTrace._(
    id: id,
    name: name,
    startedAt: DateTime.now(),
    parentId: parentId,
  );
}

/// Records a marker onto a session (used by FrameGuard).
void noteMarkerOnTrace(FrameGuardTrace? trace, FrameGuardMarker marker) {
  trace?.attachMarker(marker.id);
}
