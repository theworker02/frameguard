# Acquisition Brief â€” pubspec.yaml

**Date:** 2026-09-22  
**Repository:** https://github.com/theworker02/frameguard  
**Default branch:** `main`  
**Primary language:** Dart  
**Status:** Diligence briefing only. **No acquisition has occurred** by virtue of this file.  
**License:** Proprietary â€” sale, written commercial license, or completed asset transfer required (see root `LICENSE`).  
**Valuation:** Not stated.  
**Contact:** GitHub [@theworker02](https://github.com/theworker02) Â· [thanks.dev/u/gh/theworker02](https://thanks.dev/u/gh/theworker02)

> Cloning or forking this repository does **not** grant production, redistribution, SaaS, OEM, or commercial rights.

---

## 1. Executive thesis

<img src="branding/logo.svg" alt="FrameGuard logo" width="140" height="140" /> <strong>Performance regressions, testable.</strong><br/> Automated Flutter UI performance regression detection Ã¢â‚¬â€ budgets, baselines, and evidence-backed reports you can enforce in CI.

**Why a buyer cares:** pubspec.yaml packages transferable product IP â€” source, docs, in-repo brand assets, and a diligence room under `docs/acquisition/` â€” under a clear proprietary posture so diligence can proceed without mistaking the repo for open source.

---

## 2. Product snapshot

| Item | Detail |
|------|--------|
| Product | pubspec.yaml |
| Repo | `theworker02/frameguard` |
| Language | Dart |
| Open source? | **No** â€” proprietary |
| Rightsholder | theworker02 |
| Diligence pack | `docs/acquisition/` |

### Capability highlights (from current materials)

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

---

## 3. Problem / opportunity

Teams evaluating pubspec.yaml typically need either (a) a commercial right to run or embed it, or (b) outright ownership of the Product IP for strategic build-out. Public GitHub visibility without a proprietary license creates false assumptions about free production use. This brief and the linked data room make the commercial path explicit.

---

## 4. What ships today

Honest maturity: treat repository contents, README claims, tests, and release tags as the source of truth. Do not assume production customers, ARR, filed patents, or SLAs unless separately evidenced in diligence.

Typical transferable surfaces:

- Source tree and build/test scripts present in-repo
- Documentation and design notes
- Acquisition / diligence markdown under `docs/acquisition/`
- Branding assets committed to the repository (if any)

---

## 5. Demo / evaluation path (buyer)

Minimal path (no secrets required unless README says otherwise):

```
```yaml
# pubspec.yaml
dependencies:
  frameguard: ^0.6.0
```
```dart
import 'package:frameguard/frameguard.dart';
import 'package:frameguard/frameguard_test.dart';
```
```bash
flutter pub get
```
```dart
import 'package:flutter/material.dart';
import 'package:frameguard/frameguard.dart';

void main() {
  FrameGuard.initialize(
    config: FrameGuardConfig(
      samplingMode: SamplingMode.balanced,
      defaultBudget: FrameBudget.forRefreshRate(60, maxJankRate: 0.02),
    ),
  );

  runApp(
    const FrameGuardScope(
      child: FrameGuardOverlay(
        compact: true,
        child: MyApp(),
      ),
    ),
  );
}
```
```dart
final session = FrameGuard.startSession(name: 'home_scroll');
// Ã¢â‚¬Â¦interact with the appÃ¢â‚¬Â¦
final report = await session.stop();

debugPrint(report.summary());
```

Extended evaluation: `docs/acquisition/BUYER_EVALUATION.md`. Written NDA / evaluation grants may be required for private materials.

---

## 6. What a transaction typically includes

Subject to definitive schedules:

| Included (typical) | Excluded (typical) |
|--------------------|--------------------|
| Repo materials + asserted original IP | Seller personal accounts / unrelated repos |
| Docs + diligence room at closing | Third-party dependency source under separate licenses |
| In-repo brand marks as assigned | Secrets without rotation plan |
| Know-how captured in docs | Fabricated revenue, user, or adoption metrics |

---

## 7. Suggested deal structures

| Structure | When it fits |
|-----------|--------------|
| Non-exclusive commercial license | Deploy/run under seat or environment terms |
| Exclusive field-of-use license | Buyer wants exclusivity; seller may retain entity |
| Asset / IP assignment | Buyer wants ownership of Materials outright |
| OEM / redistribution | Separate agreement â€” not implied here |

Commercial terms (price, earnouts, escrow) are negotiated under NDA with counsel.

---

## 8. Buyer diligence checklist

- [ ] Confirm Rightsholder identity and authority to sell/license
- [ ] Inventory Materials (`docs/acquisition/ASSET_INVENTORY.md`)
- [ ] Review IP posture (`IP_PROVENANCE.md`) and dependencies (`DEPENDENCY_INVENTORY.md`)
- [ ] Run evaluation script (`BUYER_EVALUATION.md`)
- [ ] Review risks (`RISK_REGISTER.md`)
- [ ] Agree transfer scope (`TRANSFER_MANIFEST.md`) and handoff (`HANDOFF_CHECKLIST.md`)
- [ ] Supersede root `LICENSE` at closing via definitive agreement

---

## 9. Related documents

| Document | Purpose |
|----------|---------|
| `LICENSE` | Proprietary â€” no default grant |
| `docs/acquisition/README.md` | Data-room index |
| `docs/acquisition/EXECUTIVE_SUMMARY.md` | One-page thesis |
| `README.md` | Product overview |
| `SECURITY.md` | Vulnerability reporting |
| `COMMERCIAL.md` | Licensing contact path |
| `.github/FUNDING.yml` | Sponsors / thanks.dev |

---

## 10. Disclaimer

This package is informational and **does not** create a binding offer, grant of rights, or investment advice. Engage counsel for any transaction.

---

*Document version: 2.0.0 / 2026-09-22 Â· Classification: acquisition briefing*
