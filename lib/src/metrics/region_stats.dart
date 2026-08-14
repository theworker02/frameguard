/// Immutable region rebuild statistics.
class RegionStats {
  /// Creates region stats.
  const RegionStats({
    required this.name,
    required this.rebuilds,
    required this.framesObserved,
    required this.averageRebuildsPerFrame,
    required this.peakRebuildsInFrame,
    this.buildProxyTotal,
    this.parent,
  });

  /// Region name.
  final String name;

  /// Total rebuilds.
  final int rebuilds;

  /// Frames observed while region was mounted.
  final int framesObserved;

  /// Average rebuilds per frame.
  final double averageRebuildsPerFrame;

  /// Peak rebuilds in one frame.
  final int peakRebuildsInFrame;

  /// Opt-in proxy build duration total (documented as approximate).
  final Duration? buildProxyTotal;

  /// Parent region name when nested.
  final String? parent;

  /// Text block.
  String summary() {
    final buf = StringBuffer()
      ..writeln('REGION')
      ..writeln(name)
      ..writeln('Rebuilds:')
      ..writeln('$rebuilds')
      ..writeln('Frames observed:')
      ..writeln('$framesObserved')
      ..writeln('Average:')
      ..writeln(
        '${averageRebuildsPerFrame.toStringAsFixed(2)} rebuilds/frame',
      )
      ..writeln('Peak:')
      ..writeln('$peakRebuildsInFrame rebuilds in one frame');
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'name': name,
        'rebuilds': rebuilds,
        'framesObserved': framesObserved,
        'averageRebuildsPerFrame': averageRebuildsPerFrame,
        'peakRebuildsInFrame': peakRebuildsInFrame,
        if (buildProxyTotal != null)
          'buildProxyTotalMs': buildProxyTotal!.inMicroseconds / 1000.0,
        if (parent != null) 'parent': parent,
      };
}

/// Accumulates rebuild stats for a named region during a live session.
class RegionStatsAccumulator {
  /// Creates an accumulator.
  RegionStatsAccumulator(this.name);

  /// Region name.
  final String name;

  /// Total rebuilds observed.
  int rebuilds = 0;

  /// Frames observed while region was mounted.
  int framesObserved = 0;

  /// Rebuilds in the current frame window.
  int rebuildsThisFrame = 0;

  /// Peak rebuilds in one frame.
  int peakRebuildsInFrame = 0;

  /// Whether build proxy timing is enabled.
  bool measureBuild = false;

  /// Parent region name when nested.
  String? parentName;

  /// Cumulative proxy build duration.
  Duration totalBuildProxy = Duration.zero;

  /// Called when a rebuild occurs.
  void onRebuild({Duration? buildProxy}) {
    rebuilds++;
    rebuildsThisFrame++;
    if (rebuildsThisFrame > peakRebuildsInFrame) {
      peakRebuildsInFrame = rebuildsThisFrame;
    }
    if (buildProxy != null) {
      totalBuildProxy += buildProxy;
    }
  }

  /// Called once per captured frame.
  void onFrame() {
    framesObserved++;
    rebuildsThisFrame = 0;
  }

  /// Snapshot stats.
  RegionStats toStats() {
    final avg = framesObserved == 0 ? 0.0 : rebuilds / framesObserved;
    return RegionStats(
      name: name,
      rebuilds: rebuilds,
      framesObserved: framesObserved,
      averageRebuildsPerFrame: avg,
      peakRebuildsInFrame: peakRebuildsInFrame,
      buildProxyTotal: measureBuild ? totalBuildProxy : null,
      parent: parentName,
    );
  }
}
