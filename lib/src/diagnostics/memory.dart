/// Best-effort memory / GC pressure probe.
///
/// Precise GC pause events are often unavailable via public APIs. FrameGuard
/// never fabricates GC data — probes return [MemoryProbeResult.unavailable]
/// unless a real signal exists.
abstract class MemoryProbe {
  /// Samples current memory pressure signals.
  MemoryProbeResult sample();
}

/// Result of a memory probe.
class MemoryProbeResult {
  /// Creates a result.
  const MemoryProbeResult({
    required this.available,
    this.heapUsageBytes,
    this.heapCapacityBytes,
    this.externalBytes,
    this.note,
  });

  /// Unavailable probe (honest).
  factory MemoryProbeResult.unavailable([String? note]) => MemoryProbeResult(
        available: false,
        note: note ??
            'GC/memory pressure signals Unavailable on this platform/runtime.',
      );

  /// Whether any numeric signal was obtained.
  final bool available;

  /// Current heap usage when known.
  final int? heapUsageBytes;

  /// Heap capacity when known.
  final int? heapCapacityBytes;

  /// External allocations when known.
  final int? externalBytes;

  /// Human note / unavailability reason.
  final String? note;

  /// JSON map.
  Map<String, Object?> toJson() => {
        'available': available,
        if (heapUsageBytes != null) 'heapUsageBytes': heapUsageBytes,
        if (heapCapacityBytes != null) 'heapCapacityBytes': heapCapacityBytes,
        if (externalBytes != null) 'externalBytes': externalBytes,
        if (note != null) 'note': note,
      };
}

/// Default probe that reports Unavailable rather than inventing GC pauses.
class UnavailableMemoryProbe implements MemoryProbe {
  /// Creates the probe.
  const UnavailableMemoryProbe();

  @override
  MemoryProbeResult sample() => MemoryProbeResult.unavailable();
}

/// Tracks allocation growth between two probe snapshots when available.
class MemoryPressureTracker {
  /// Creates a tracker.
  MemoryPressureTracker({MemoryProbe probe = const UnavailableMemoryProbe()})
      : _probe = probe;

  final MemoryProbe _probe;
  MemoryProbeResult? _start;
  MemoryProbeResult? _end;

  /// Records the start sample.
  void begin() => _start = _probe.sample();

  /// Records the end sample.
  void end() => _end = _probe.sample();

  /// Growth summary for reports.
  MemoryPressureSummary summarize({String? during}) {
    final start = _start;
    final end = _end;
    if (start == null ||
        end == null ||
        !start.available ||
        !end.available ||
        start.heapUsageBytes == null ||
        end.heapUsageBytes == null) {
      return MemoryPressureSummary(
        available: false,
        during: during,
        note: end?.note ??
            start?.note ??
            'Memory pressure Unavailable — no public GC event stream.',
      );
    }
    final delta = end.heapUsageBytes! - start.heapUsageBytes!;
    return MemoryPressureSummary(
      available: true,
      during: during,
      growthBytes: delta,
      startBytes: start.heapUsageBytes,
      endBytes: end.heapUsageBytes,
      note: delta > 0
          ? 'Allocation growth observed. GC pressure may contribute to '
              'frame instability (heuristic — not a measured GC pause).'
          : 'No allocation growth observed between probes.',
    );
  }
}

/// Human-readable memory pressure summary for reports.
class MemoryPressureSummary {
  /// Creates a summary.
  const MemoryPressureSummary({
    required this.available,
    this.during,
    this.growthBytes,
    this.startBytes,
    this.endBytes,
    this.note,
  });

  /// Whether numeric growth was measured.
  final bool available;

  /// Scenario/interaction label.
  final String? during;

  /// Byte growth (end - start).
  final int? growthBytes;

  /// Start heap bytes.
  final int? startBytes;

  /// End heap bytes.
  final int? endBytes;

  /// Explanation / unavailability note.
  final String? note;

  /// Text block matching product language.
  String summary() {
    if (!available) {
      return 'MEMORY PRESSURE\nUnavailable\n${note ?? ''}';
    }
    final mb = (growthBytes ?? 0) / (1024 * 1024);
    final buf = StringBuffer()
      ..writeln('MEMORY PRESSURE')
      ..writeln('Allocation growth during:')
      ..writeln(during ?? '(session)')
      ..writeln('Observed:')
      ..writeln('${mb >= 0 ? '+' : ''}${mb.toStringAsFixed(1)} MB')
      ..writeln('Possible effect:')
      ..writeln(note ?? '');
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'available': available,
        if (during != null) 'during': during,
        if (growthBytes != null) 'growthBytes': growthBytes,
        if (startBytes != null) 'startBytes': startBytes,
        if (endBytes != null) 'endBytes': endBytes,
        if (note != null) 'note': note,
      };
}
