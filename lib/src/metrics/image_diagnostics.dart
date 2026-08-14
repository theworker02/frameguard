/// Image size warning produced by diagnostics.
class ImageWarning {
  /// Creates a warning.
  const ImageWarning({
    required this.description,
    required this.displayWidth,
    required this.displayHeight,
    required this.decodedWidth,
    required this.decodedHeight,
    required this.estimatedDecodedBytes,
  });

  /// Image description / asset path.
  final String description;

  /// Display width in logical pixels.
  final double displayWidth;

  /// Display height in logical pixels.
  final double displayHeight;

  /// Decoded pixel width.
  final int decodedWidth;

  /// Decoded pixel height.
  final int decodedHeight;

  /// Estimated decoded memory (RGBA ≈ 4 bytes/pixel).
  final int estimatedDecodedBytes;

  /// Whether dramatically oversized (≥ 4× area).
  bool get dramaticallyOversized {
    final displayArea = displayWidth * displayHeight;
    if (displayArea <= 0) return false;
    final decodedArea = decodedWidth * decodedHeight;
    return decodedArea >= displayArea * 4;
  }

  /// One-line evidence string.
  String get summaryLine =>
      '$description display ${displayWidth.toInt()}×${displayHeight.toInt()} '
      'decoded $decodedWidth×$decodedHeight '
      '(~${(estimatedDecodedBytes / (1024 * 1024)).toStringAsFixed(1)} MB)';

  /// Full text block.
  String summary() {
    final buf = StringBuffer()
      ..writeln('IMAGE WARNING')
      ..writeln('Image:')
      ..writeln(description)
      ..writeln('Display size:')
      ..writeln('${displayWidth.toInt()} × ${displayHeight.toInt()}')
      ..writeln('Decoded size:')
      ..writeln('$decodedWidth × $decodedHeight')
      ..writeln('Estimated decoded memory:')
      ..writeln(
        '${(estimatedDecodedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      );
    if (dramaticallyOversized) {
      buf.writeln('Likely issue:');
      buf.writeln(
        'Image is dramatically oversized for its rendered dimensions.',
      );
    }
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'description': description,
        'displayWidth': displayWidth,
        'displayHeight': displayHeight,
        'decodedWidth': decodedWidth,
        'decodedHeight': decodedHeight,
        'estimatedDecodedBytes': estimatedDecodedBytes,
        'dramaticallyOversized': dramaticallyOversized,
      };
}

/// Snapshot of Flutter's image cache.
class ImageCacheSnapshot {
  /// Creates a snapshot.
  const ImageCacheSnapshot({
    required this.currentEntries,
    required this.currentBytes,
    required this.liveEntries,
    required this.peakEntries,
    required this.peakBytes,
    required this.evictions,
  });

  /// Current cached entries.
  final int currentEntries;

  /// Current estimated bytes.
  final int currentBytes;

  /// Live image count.
  final int liveEntries;

  /// Peak entries during scenario.
  final int peakEntries;

  /// Peak bytes during scenario.
  final int peakBytes;

  /// Evictions observed during scenario (best-effort).
  final int evictions;

  /// Text block.
  String summary() {
    final buf = StringBuffer()
      ..writeln('IMAGE CACHE')
      ..writeln('Peak entries:')
      ..writeln('$peakEntries')
      ..writeln('Peak bytes:')
      ..writeln('${(peakBytes / (1024 * 1024)).toStringAsFixed(0)} MB')
      ..writeln('Evictions during scenario:')
      ..writeln('$evictions');
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'currentEntries': currentEntries,
        'currentBytes': currentBytes,
        'liveEntries': liveEntries,
        'peakEntries': peakEntries,
        'peakBytes': peakBytes,
        'evictions': evictions,
      };
}
