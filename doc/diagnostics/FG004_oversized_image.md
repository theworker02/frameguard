# FG004 — Oversized Image

## What it means

Decoded image pixel dimensions are dramatically larger than the display size (≈4× area or more), implying wasted decode/memory bandwidth.

## How FrameGuard detects it

`FrameGuardImage` compares provider-decoded size to layout/display size when both are known. Estimated memory assumes RGBA (4 bytes/px).

FrameGuard does **not** claim which thread performed decoding.

## Possible fixes

- `cacheWidth` / `cacheHeight`
- Resolution-appropriate assets
- Avoid large decodes during animations

## False positives

Images intentionally decoded large for zoom/hero transitions.
