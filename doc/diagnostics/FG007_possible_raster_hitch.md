# FG007 — Possible Raster Hitch

## What it means

**Heuristic:** raster duration spiked while build stayed low — consistent with first-playback hitches (shader compilation, expensive clipping, saveLayer, large image rasterization).

FrameGuard does **not** claim direct shader compilation detection unless the engine exposes it.

## Evidence language

Reports use “Possible raster hitch” and list possible causes — never guaranteed attribution.
