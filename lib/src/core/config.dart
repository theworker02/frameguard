import 'package:frameguard/src/core/sampling_mode.dart';
import 'package:frameguard/src/metrics/budget.dart';
import 'package:frameguard/src/metrics/budget_profile.dart';
import 'package:frameguard/src/metrics/jank.dart';
import 'package:frameguard/src/metrics/refresh_rate.dart';
import 'package:frameguard/src/reporting/comparison.dart';

/// Global configuration for FrameGuard.
///
/// Pass to [FrameGuard.initialize]. YAML project config is optional; Dart
/// configuration is the primary API.
class FrameGuardConfig {
  /// Creates a FrameGuard configuration.
  const FrameGuardConfig({
    this.samplingMode = SamplingMode.balanced,
    this.jankPolicy = const JankPolicy(),
    this.defaultBudget,
    this.refreshRate = RefreshRate.auto,
    this.refreshRateFallbackHz = 60,
    this.maxFrames = 10000,
    this.ringBuffer = true,
    this.enableOverlayInRelease = false,
    this.profiles = const {},
    this.regressionThresholds = const RegressionThresholds(),
    this.minSampleCount = 30,
    this.warnOnDebugMode = true,
  });

  /// Lightweight preset: frames + markers only.
  factory FrameGuardConfig.lightweight() => const FrameGuardConfig(
        samplingMode: SamplingMode.lightweight,
      );

  /// Full diagnostics preset.
  factory FrameGuardConfig.full() => const FrameGuardConfig(
        samplingMode: SamplingMode.full,
      );

  /// How aggressively to collect diagnostics.
  final SamplingMode samplingMode;

  /// Policy for classifying jank severity.
  final JankPolicy jankPolicy;

  /// Default performance budget applied when none is specified.
  final FrameBudget? defaultBudget;

  /// Target refresh rate strategy.
  final RefreshRate refreshRate;

  /// Fallback Hz when auto-detection fails. Documented in reports.
  final double refreshRateFallbackHz;

  /// Maximum frames retained per session (bounded memory).
  final int maxFrames;

  /// When true and [maxFrames] is exceeded, drop oldest frames.
  final bool ringBuffer;

  /// Allow the runtime overlay in release builds when explicitly enabled.
  final bool enableOverlayInRelease;

  /// Named budget profiles (`strict`, `mid_range`, etc.).
  final Map<String, BudgetProfile> profiles;

  /// Thresholds used when classifying regression magnitude.
  final RegressionThresholds regressionThresholds;

  /// Minimum frames before certain detectors fire (false-positive control).
  final int minSampleCount;

  /// Emit a prominent warning when capturing in debug mode.
  final bool warnOnDebugMode;
}
