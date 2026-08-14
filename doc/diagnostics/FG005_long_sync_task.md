# FG005 — Long Sync Task

## What it means

`FrameGuard.measureTask` observed synchronous (or blocking async) work exceeding the UI-thread budget, optionally overlapping slow frames.

## How FrameGuard detects it

Wall-clock duration around the measured body vs configured `syncTaskBudget` (default 8ms). Overlap count uses session frame timestamps.

## Possible fixes

- Background isolates for parse/compute
- Chunk work across frames
- Cache expensive results
