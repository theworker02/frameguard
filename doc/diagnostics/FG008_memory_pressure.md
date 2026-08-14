# FG008 — Memory Pressure

## What it means

Allocation growth / GC pressure *may* contribute to frame instability.

## Availability

Precise GC pause events are often **Unavailable** via public APIs. FrameGuard reports Unavailable rather than fabricating GC data. Hooks exist for future platform adapters.
