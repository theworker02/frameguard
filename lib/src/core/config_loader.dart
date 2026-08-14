import 'package:frameguard/src/core/config.dart';
import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/core/sampling_mode.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/budget_profile.dart';
import 'package:frameguard/src/metrics/jank.dart';
import 'package:frameguard/src/metrics/refresh_rate.dart';
import 'package:frameguard/src/reporting/comparison.dart';

/// Loads optional project configuration into a [FrameGuardConfig].
///
/// Supports a small YAML subset used by `frameguard.yaml`. Dart configuration
/// remains the primary API — YAML is never required.
class FrameGuardConfigLoader {
  FrameGuardConfigLoader._();

  /// Parses YAML text into a [FrameGuardConfig].
  ///
  /// Expected shape:
  /// ```yaml
  /// frameguard:
  ///   refresh_rate: auto  # or 60 / 90 / 120
  ///   sampling_mode: balanced
  ///   budgets:
  ///     max_jank_rate: 0.01
  ///     max_p95_ms: 16
  ///   profiles:
  ///     mid_range:
  ///       max_jank_rate: 0.02
  /// ```
  static FrameGuardConfig fromYaml(String yamlText) {
    final root = _SimpleYaml.parse(yamlText);
    final fg = root['frameguard'];
    if (fg is! Map) {
      throw FrameGuardException(
        'Invalid frameguard.yaml.\n'
        'Expected a top-level "frameguard:" map.\n'
        'See frameguard.yaml.example for the supported shape.',
      );
    }
    final map = Map<String, Object?>.from(fg);

    final sampling = _samplingMode(map['sampling_mode']?.toString());
    final refresh = _refreshRate(map['refresh_rate']);
    final fallback =
        (map['refresh_rate_fallback_hz'] as num?)?.toDouble() ?? 60;
    final budgets = map['budgets'];
    final defaultBudget =
        budgets is Map ? _budget(Map<String, Object?>.from(budgets)) : null;

    final profilesRaw = map['profiles'];
    final profiles = <String, BudgetProfile>{};
    if (profilesRaw is Map) {
      for (final entry in profilesRaw.entries) {
        final name = entry.key.toString();
        final value = entry.value;
        if (value is Map) {
          profiles[name] = BudgetProfile(
            name: name,
            budget: _budget(Map<String, Object?>.from(value)),
          );
        }
      }
    }

    final jank = map['jank_policy'];
    var policy = const JankPolicy();
    if (jank is Map) {
      final j = Map<String, Object?>.from(jank);
      policy = JankPolicy(
        minorMultiplier: (j['minor_multiplier'] as num?)?.toDouble() ?? 1.0,
        majorMultiplier: (j['major_multiplier'] as num?)?.toDouble() ?? 2.0,
        severeMultiplier: (j['severe_multiplier'] as num?)?.toDouble() ?? 4.0,
      );
    }

    return FrameGuardConfig(
      samplingMode: sampling,
      jankPolicy: policy,
      defaultBudget: defaultBudget,
      refreshRate: refresh,
      refreshRateFallbackHz: fallback,
      maxFrames: (map['max_frames'] as num?)?.toInt() ?? 10000,
      ringBuffer: map['ring_buffer'] as bool? ?? true,
      profiles: profiles,
      minSampleCount: (map['min_sample_count'] as num?)?.toInt() ?? 30,
      warnOnDebugMode: map['warn_on_debug_mode'] as bool? ?? true,
      regressionThresholds: const RegressionThresholds(),
    );
  }

  static SamplingMode _samplingMode(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'full':
        return SamplingMode.full;
      case 'lightweight':
        return SamplingMode.lightweight;
      case 'balanced':
      case null:
        return SamplingMode.balanced;
      default:
        throw FrameGuardException(
          'Unknown sampling_mode "$raw". Use full, balanced, or lightweight.',
        );
    }
  }

  static RefreshRate _refreshRate(Object? raw) {
    if (raw == null || raw.toString() == 'auto') return RefreshRate.auto;
    final hz = double.tryParse(raw.toString());
    if (hz == null || hz <= 0) {
      throw FrameGuardException(
        'Invalid refresh_rate "$raw". Use auto or a positive Hz value.',
      );
    }
    return RefreshRate.hz(hz);
  }

  static FrameBudget _budget(Map<String, Object?> map) {
    Duration? ms(String key) {
      final v = map[key];
      if (v is num) return Duration(microseconds: (v * 1000).round());
      return null;
    }

    return FrameBudget(
      maxJankFrames: (map['max_jank_frames'] as num?)?.toInt(),
      maxJankRate: (map['max_jank_rate'] as num?)?.toDouble(),
      maxP50FrameTime: ms('max_p50_ms'),
      maxP95FrameTime: ms('max_p95_ms'),
      maxP99FrameTime: ms('max_p99_ms'),
      maxFrameTime: ms('max_frame_ms'),
      maxBuildDuration: ms('max_build_ms'),
      maxRasterDuration: ms('max_raster_ms'),
      maxSevereJankFrames: (map['max_severe_jank_frames'] as num?)?.toInt(),
      maxAverageFrameTime: ms('max_average_ms'),
    );
  }
}

/// Minimal indentation-based YAML subset parser for FrameGuard config.
///
/// Not a general YAML implementation — only maps, scalars, and nesting
/// used by `frameguard.yaml`.
class _SimpleYaml {
  static Map<String, Object?> parse(String text) {
    final lines =
        text.split('\n').map((l) => l.replaceAll('\t', '  ')).where((l) {
      final t = l.trim();
      return t.isNotEmpty && !t.startsWith('#');
    }).toList();
    var i = 0;

    Map<String, Object?> parseMap(int indent) {
      final map = <String, Object?>{};
      while (i < lines.length) {
        final line = lines[i];
        final currentIndent = line.length - line.trimLeft().length;
        if (currentIndent < indent) break;
        if (currentIndent > indent) {
          throw FrameGuardException(
            'Invalid YAML indentation near: ${line.trim()}',
          );
        }
        final trimmed = line.trim();
        final colon = trimmed.indexOf(':');
        if (colon < 0) {
          throw FrameGuardException('Expected key: value near: $trimmed');
        }
        final key = trimmed.substring(0, colon).trim();
        final rest = trimmed.substring(colon + 1).trim();
        i++;
        if (rest.isEmpty) {
          if (i < lines.length) {
            final next = lines[i];
            final nextIndent = next.length - next.trimLeft().length;
            if (nextIndent > currentIndent) {
              map[key] = parseMap(nextIndent);
              continue;
            }
          }
          map[key] = null;
        } else {
          map[key] = _scalar(rest);
        }
      }
      return map;
    }

    return parseMap(0);
  }

  static Object? _scalar(String raw) {
    // Strip inline comments (unquoted).
    var value = raw;
    final hash = value.indexOf('#');
    if (hash >= 0 &&
        !value.trimLeft().startsWith('"') &&
        !value.trimLeft().startsWith("'")) {
      value = value.substring(0, hash).trim();
    } else {
      value = value.trim();
    }
    if (value.isEmpty || value == 'null' || value == '~') return null;
    if (value == 'true') return true;
    if (value == 'false') return false;
    final asNum = num.tryParse(value);
    if (asNum != null) return asNum;
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
