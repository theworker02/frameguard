# Asset inventory â€” pubspec.yaml

## Repository surfaces

| Asset | Location / notes |
|-------|------------------|
| Source tree | Repository root / language packages |
| Tests | `test/`, `tests/`, CI workflows if present |
| Docs | `README.md`, `docs/` |
| Diligence room | `docs/acquisition/` |
| License / notices | `LICENSE`, transition notices if present |
| Funding | `.github/FUNDING.yml` |
| CI | `.github/workflows/` if present |
| Branding | logos/assets folders if present |

## Capability highlights

- **Session capture** via `SchedulerBinding.addTimingsCallback` / `FrameTiming`
- **Refresh-rate-aware budgets** (60 / 90 / 120 / 144 Hz Ã¢â‚¬â€ no hardcoded 16.67 ms dogma)
- **Jank severity** (healthy / minor / major / severe)
- **Percentiles** Ã¢â‚¬â€ p50 / p90 / p95 / p99, histograms, streaks
- **Build vs raster** classification (derived, never claimed as certainty)
- **Regions & rebuild counts** (`FrameGuardRegion`)
- **Traces, markers, sync tasks**
- **Explainability + recommendations** tied to evidence (`FG001`Ã¢â‚¬â€œ`FG010`)
- **JSON / text / HTML** reports (versioned schema)
- **CSV Ã‚Â· JUnit Ã‚Â· SARIF Ã‚Â· Markdown** exporters for CI / PR comments
- **Baselines & golden files** (never silently overwritten)
- **Multi-run statistics** (median, MAD, CI; outliers flagged, not deleted)

## Usually excluded

Seller personal accounts, unrelated repos, and unreissued registry tokens â€” unless listed in the definitive agreement.

*Updated: 2026-09-22*
