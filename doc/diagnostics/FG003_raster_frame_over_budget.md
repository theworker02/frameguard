# FG003 — Raster Frame Over Budget

## What it means

Slow frames were predominantly **raster-bound**.

## How FrameGuard detects it

Same bottleneck classifier as FG002, but raster duration dominates.

## Common causes

- Complex clipping / `saveLayer`
- Heavy shadows, opacity, backdrop filters
- Oversized images during scroll/animation

## Possible fixes

- Inspect clipping and saveLayer usage
- Reduce overdraw and complex shadows
- Check oversized images (see FG004)

## False positives

First-frame raster spikes may be hitch patterns (FG007) rather than sustained raster cost.
