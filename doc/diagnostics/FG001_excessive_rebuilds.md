# FG001 — Excessive Rebuilds

## What it means

An instrumented `FrameGuardRegion` rebuilt far more often than expected during a scenario — either high total rebuilds, high average rebuilds/frame, or a large peak burst in a single frame.

## How FrameGuard detects it

- Counts `build` invocations of `FrameGuardRegion` while a session is active.
- Correlates peaks with frame ticks recorded from `FrameTiming`.
- Fires when rebuilds ≥ 20 or peak ≥ 5/frame (heuristic thresholds; suppressible).

## Common causes

- Broad `setState` / `notifyListeners` invalidating large subtrees
- Animations rebuilding entire lists every tick
- Missing `const` / selectors that return new objects each build

## How to investigate

1. Open the rebuild heatmap in the report.
2. Identify the region with the highest peak.
3. Check what listenables/providers sit above that region.
4. Reproduce with `FrameGuardTest.measure` around the interaction.

## Possible fixes

- Isolate rapidly changing state
- Narrow rebuild scope
- Use `const` widgets where appropriate
- Inspect selectors/listeners that invalidate the region

## False positives

- Intentionally animated regions may rebuild every frame by design — use `FrameGuardSuppress` sparingly or raise region budgets.
