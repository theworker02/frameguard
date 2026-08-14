import 'package:frameguard/src/metrics/percentiles.dart';

/// Frame-time histogram with fixed millisecond buckets.
class FrameHistogram {
  /// Default buckets used in text and HTML reports.
  static const List<(double, double?)> defaultBucketsMs = [
    (0, 4),
    (4, 8),
    (8, 12),
    (12, 16),
    (16, 24),
    (24, 32),
    (32, 50),
    (50, null),
  ];

  /// Creates a histogram from [counts] keyed by bucket labels.
  const FrameHistogram({
    required this.buckets,
    required this.counts,
  });

  /// Bucket labels (e.g. `0–4 ms`, `50+ ms`).
  final List<String> buckets;

  /// Counts aligned with [buckets].
  final List<int> counts;

  /// Builds a histogram from total frame durations.
  factory FrameHistogram.fromDurations(
    Iterable<Duration> durations, {
    List<(double, double?)> bucketEdgesMs = defaultBucketsMs,
  }) {
    final labels = <String>[];
    final counts = List<int>.filled(bucketEdgesMs.length, 0);
    for (final (lo, hi) in bucketEdgesMs) {
      labels.add(
          hi == null ? '${lo.toInt()}+ ms' : '${lo.toInt()}–${hi.toInt()} ms');
    }
    for (final d in durations) {
      final ms = d.inMicroseconds / 1000.0;
      for (var i = 0; i < bucketEdgesMs.length; i++) {
        final (lo, hi) = bucketEdgesMs[i];
        if (ms >= lo && (hi == null || ms < hi)) {
          counts[i]++;
          break;
        }
      }
    }
    return FrameHistogram(buckets: labels, counts: counts);
  }

  /// ASCII bar chart suitable for terminals without color.
  String toAscii({int width = 40}) {
    if (counts.isEmpty) return '(empty histogram)';
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    final buf = StringBuffer();
    for (var i = 0; i < buckets.length; i++) {
      final barLen =
          maxCount == 0 ? 0 : ((counts[i] / maxCount) * width).round();
      final bar = '#' * barLen;
      buf.writeln(
          '${buckets[i].padRight(12)} ${counts[i].toString().padLeft(5)} $bar');
    }
    return buf.toString().trimRight();
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'buckets': buckets,
        'counts': counts,
      };
}

/// Convenience: percentile labels for a sorted duration list.
Map<String, double> percentileTableMs(List<Duration> sortedTotals) => {
      'p50': Percentiles.percentile(sortedTotals, 50).inMicroseconds / 1000.0,
      'p90': Percentiles.percentile(sortedTotals, 90).inMicroseconds / 1000.0,
      'p95': Percentiles.percentile(sortedTotals, 95).inMicroseconds / 1000.0,
      'p99': Percentiles.percentile(sortedTotals, 99).inMicroseconds / 1000.0,
    };
