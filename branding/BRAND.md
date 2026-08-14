# FrameGuard brand

**Tagline:** Performance regressions, testable.

**One-liner:** Turn Flutter frame timings into actionable, CI-enforceable explanations — locally, with no backend.

## Voice

- Precise, not theatrical
- Evidence before advice
- Honest about Unavailable metrics
- Developer-to-developer, no marketing fog

Prefer:

> 15 of 21 janky frames were build-bound; `product_grid` peaked at 13 rebuilds/frame.

Avoid:

> Supercharge your Flutter app’s buttery-smooth UX! 🚀

## Name

- **Product:** FrameGuard
- **Package:** `frameguard`
- **CLI:** `frameguard`
- **Diagnostic IDs:** `FG001` …

Do not stylize as Frame Guard, frameGuard, or FG (except compact overlay `FG`).

## Color

| Token | Hex | Use |
|-------|-----|-----|
| `ink` | `#1A3A3A` | Primary mark, headlines |
| `slate` | `#2F4F4F` | Secondary UI chrome |
| `stone` | `#5C6B6B` | Body / muted |
| `paper` | `#F4F6F5` | Surfaces |
| `signal` | `#C45C26` | Fail / jank emphasis (sparingly) |
| `pass` | `#2F6F4E` | Pass / healthy |

Avoid purple-on-white gradients, neon glow, and generic AI-cream+terracotta stacks.

## Typography

- Display / brand: geometric sans with open counters (e.g. **Sora**, **Outfit**, or **DM Sans**)
- Code / reports: **IBM Plex Mono** or **JetBrains Mono**
- Do not use Inter/Roboto/Arial as the brand face in marketing surfaces

## Logo

Assets in `/branding` (SVGs are source of truth; PNGs are raster exports for pub.dev / GitHub):

| File | Use |
|------|-----|
| `logo.svg` / `logo.png` | Icon / avatar / pub.dev |
| `banner.svg` / `banner.png` | README hero / social |
| `favicon.svg` | Browser / site favicon |
| `tokens.css` | Shared CSS variables |
| `report-preview.png` | Feature screenshot |

**Mark concept:** a filled dual-bezel viewport chassis with corner registration brackets, a top timing ruler (one signal-colored jank tick aligned to the spike), an interior dual-tone frame-duration histogram crossed by a dashed green budget/guard line, and a shield-check badge — frame timings under protection.

**Clear space:** ≥ 1/8 of the mark’s width on all sides.  
**Minimum size:** 24×24 px digital.  
**Don’t:** add drop shadows, recolor to purple, stretch, or place on busy photography.

## Site

Public docs site (GitHub Pages): `docs/` → https://theworker02.github.io/frameguard/

## Funding

- GitHub Sponsors: `theworker02`
- thanks.dev: https://thanks.dev/u/gh/theworker02

## Overlay copy

Compact overlay mode:

```text
FG 120Hz
8.1ms
JANK 0.4%
```

## Boilerplate blurb (pub.dev / GitHub About)

> FrameGuard detects Flutter UI performance regressions — budgets, baselines, and evidence-backed reports you can enforce in CI. Local by default. No telemetry.
