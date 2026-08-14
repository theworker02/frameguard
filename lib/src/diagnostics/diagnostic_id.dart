/// Stable diagnostic identifiers for filtering, suppression, and docs.
enum FrameDiagnostic {
  /// FG001 — Excessive rebuilds in an instrumented region.
  excessiveRebuilds(id: 'FG001', code: 'excessive_rebuilds'),

  /// FG002 — Build-side frame over budget.
  buildFrameOverBudget(id: 'FG002', code: 'build_frame_over_budget'),

  /// FG003 — Raster-side frame over budget.
  rasterFrameOverBudget(id: 'FG003', code: 'raster_frame_over_budget'),

  /// FG004 — Oversized decoded image relative to display size.
  oversizedImage(id: 'FG004', code: 'oversized_image'),

  /// FG005 — Long synchronous UI-isolate task.
  longSyncTask(id: 'FG005', code: 'long_sync_task'),

  /// FG006 — Baseline regression vs previous run.
  baselineRegression(id: 'FG006', code: 'baseline_regression'),

  /// FG007 — Possible raster hitch pattern (heuristic).
  possibleRasterHitch(id: 'FG007', code: 'possible_raster_hitch'),

  /// FG008 — Memory / GC pressure hint (when signals exist).
  memoryPressure(id: 'FG008', code: 'memory_pressure'),

  /// FG009 — Missed frame deadline streak.
  jankStreak(id: 'FG009', code: 'jank_streak'),

  /// FG010 — Debug-mode measurement warning.
  debugModeMeasurement(id: 'FG010', code: 'debug_mode_measurement');

  const FrameDiagnostic({required this.id, required this.code});

  /// Stable ID (e.g. `FG001`).
  final String id;

  /// Snake-case code.
  final String code;

  /// Lookup by ID string.
  static FrameDiagnostic? fromId(String id) {
    for (final d in FrameDiagnostic.values) {
      if (d.id == id || d.code == id) return d;
    }
    return null;
  }
}

/// Confidence category — never fake precision like 94.284%.
enum DiagnosticConfidence {
  /// Weak or single-signal evidence.
  low,

  /// Multiple corroborating signals.
  medium,

  /// Strong, consistent evidence across frames/regions.
  high,
}
