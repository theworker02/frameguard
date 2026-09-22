# Buyer evaluation â€” pubspec.yaml

## Goal

In 15â€“45 minutes, verify the Product builds or runs as documented and that proprietary notices are present.

## Steps

1. Confirm root `LICENSE` is proprietary and `ACQUISITION.md` exists.
2. Skim `README.md` install/run claims.
3. Execute:

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

4. Run tests if present (`npm test`, `pytest`, `cargo test`, `go test ./...`, etc.).
5. Record README vs observed behavior gaps in workpapers.

## Pass criteria

- [ ] Clone succeeds
- [ ] Documented happy path works **or** failure is explained
- [ ] Minimal path needs no surprise secrets
- [ ] License notices intact

*Updated: 2026-09-22*
