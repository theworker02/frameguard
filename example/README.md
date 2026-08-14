# FrameGuard Example

Benchmark / demo application for **FrameGuard**.

![FrameGuard](../branding/logo.png)

## Run

If platform folders are missing (fresh clone of a package-only example):

```bash
cd example
flutter create . --project-name frameguard_example
flutter pub get
flutter run --profile
```

Prefer **profile** mode — debug timings are not production-representative (FrameGuard will warn).

## Scenarios

| Screen | Intent |
|--------|--------|
| Healthy List | Control — smooth scrolling |
| Rebuild Storm | Excessive rebuilds / build-bound jank |
| Oversized Images | Decode / size diagnostics |
| Heavy Layout | Layout / build cost |
| CPU Stall | Sync UI-isolate work (`measureTask`) |
| Raster Stress | Shadows / filters / raster-bound patterns |
| Animation Jank | Hitch during animation |

Open a scenario, interact, then dismiss the session report dialog.

Reports are written to `reports/<scenario>.json` so you can immediately run:

```bash
dart run frameguard inspect reports/healthy_list.json
dart run frameguard check reports/ --baseline ../test/fixtures/baselines/healthy_scroll.json
```

## Branding

Colors follow [branding/BRAND.md](../branding/BRAND.md): ink `#1A3A3A`, signal `#C45C26`, pass `#2F6F4E`.
