/// Percentile and central-tendency helpers over duration samples.
class Percentiles {
  Percentiles._();

  /// Returns the [p]-th percentile (0–100) of [sorted] durations.
  ///
  /// [sorted] must already be sorted ascending. Uses linear interpolation
  /// between nearest ranks.
  static Duration percentile(List<Duration> sorted, double p) {
    if (sorted.isEmpty) return Duration.zero;
    if (sorted.length == 1) return sorted.first;
    final clamped = p.clamp(0.0, 100.0);
    final rank = (clamped / 100.0) * (sorted.length - 1);
    final low = rank.floor();
    final high = rank.ceil();
    if (low == high) return sorted[low];
    final weight = rank - low;
    final a = sorted[low].inMicroseconds;
    final b = sorted[high].inMicroseconds;
    return Duration(microseconds: (a + (b - a) * weight).round());
  }

  /// Arithmetic mean.
  static Duration mean(List<Duration> values) {
    if (values.isEmpty) return Duration.zero;
    var sum = 0;
    for (final v in values) {
      sum += v.inMicroseconds;
    }
    return Duration(microseconds: sum ~/ values.length);
  }

  /// Median (p50).
  static Duration median(List<Duration> sorted) => percentile(sorted, 50);

  /// Maximum value, or zero if empty.
  static Duration max(List<Duration> values) {
    if (values.isEmpty) return Duration.zero;
    var m = values.first;
    for (final v in values) {
      if (v > m) m = v;
    }
    return m;
  }

  /// Population standard deviation in microseconds (as Duration of that σ).
  static Duration stdDev(List<Duration> values) {
    if (values.length < 2) return Duration.zero;
    final m = mean(values).inMicroseconds.toDouble();
    var acc = 0.0;
    for (final v in values) {
      final d = v.inMicroseconds - m;
      acc += d * d;
    }
    final variance = acc / values.length;
    return Duration(microseconds: variance.sqrt().round());
  }

  /// Median absolute deviation (robust scale).
  static Duration mad(List<Duration> sorted) {
    if (sorted.isEmpty) return Duration.zero;
    final med = median(sorted).inMicroseconds;
    final deviations = sorted
        .map((d) => Duration(microseconds: (d.inMicroseconds - med).abs()))
        .toList()
      ..sort();
    return median(deviations);
  }

  /// Mean after trimming [trimFraction] from each tail (0–0.49).
  static Duration trimmedMean(List<Duration> sorted, double trimFraction) {
    if (sorted.isEmpty) return Duration.zero;
    final fraction = trimFraction.clamp(0.0, 0.49);
    final trim = (sorted.length * fraction).floor();
    if (trim * 2 >= sorted.length) return median(sorted);
    return mean(sorted.sublist(trim, sorted.length - trim));
  }
}

extension on double {
  double sqrt() {
    // Newton-Raphson for positive values; Duration σ is always ≥ 0.
    if (this <= 0) return 0;
    var x = this;
    for (var i = 0; i < 16; i++) {
      x = 0.5 * (x + this / x);
    }
    return x;
  }
}
