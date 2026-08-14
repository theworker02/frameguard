# FG006 — Baseline Regression

## What it means

Current metrics exceeded comparison thresholds relative to a stored baseline (relative and/or absolute).

## How FrameGuard detects it

`FrameGuardCompare` evaluates p95, p99, and jank rate against `ComparisonThresholds`. Magnitude uses documented `RegressionThresholds`.

## Notes

Environment mismatches produce warnings; `--require-matching-environment` fails hard.
