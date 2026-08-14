# FG002 — Build Frame Over Budget

## What it means

Slow frames were predominantly **build-bound**: Dart/UI work dominated `FrameTiming.buildDuration` relative to raster.

## How FrameGuard detects it

- Classifies each frame with a dominance threshold (≥55% of build+raster, ≥2ms).
- Ranks the worst frames; if most are build-bound, FG002 is raised.
- This is a **derived classification**, not certainty.

## Common causes

- Expensive `build` methods
- Large widget trees dirty at once
- Synchronous JSON parsing / decoding on the UI isolate during build

## How to investigate

Review the slowest-frames table (build vs raster columns) and correlated regions/markers.

## Possible fixes

- Profile dirty widgets during the slow window
- Defer non-critical work
- Split large subtrees; cache derived values outside build

## False positives

Mixed frames near the dominance threshold may flip between build/raster — treat medium confidence accordingly.
