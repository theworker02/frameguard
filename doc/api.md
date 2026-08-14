# FrameGuard API cookbook

Practical recipes for the most common workflows. Prefer **profile** mode for
any gate you care about.

## Initialize once

```dart
FrameGuard.initialize(
  config: FrameGuardConfig(
    samplingMode: SamplingMode.balanced,
    defaultBudget: BudgetProfile.midRange60().budget,
  ),
);

runApp(const FrameGuardScope(child: MyApp()));
```

## Capture a session

```dart
final report = await FrameGuard.runSession(
  name: 'home_scroll',
  body: () async {
    await scrollHome();
  },
);

await report.writeJson(File('reports/home_scroll.json'));
await report.writeHtml(File('reports/home_scroll.html'));
```

Or manually:

```dart
final session = FrameGuard.startSession(name: 'home_scroll');
// interact…
final report = await session.stop();
```

## Assert in widget tests

```dart
import 'package:frameguard/frameguard_test.dart';

testWidgets('catalog stays within budget', (tester) async {
  await tester.pumpWidget(const App());
  final report = await FrameGuardTest.measure(
    tester,
    name: 'catalog',
    action: () async {
      await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
      await tester.pumpAndSettle();
    },
  );
  expect(report, meetsFrameBudget(BudgetProfile.midRange60().budget));
});
```

## Golden baselines

```dart
await FrameGuardGolden.expectMatches(report, 'catalog');
// deliberate update:
await FrameGuardGolden.update(report, 'catalog', overwrite: true);
```

CLI:

```bash
dart run frameguard baseline update reports/catalog.json --out baselines/catalog.json
dart run frameguard check reports/catalog.json --baseline baselines/catalog.json
```

## PR comment Markdown

```bash
dart run frameguard export reports/catalog.json --format markdown --out summary.md
# or
dart run frameguard summary reports/catalog.json --format markdown
```

## Doctor

```bash
dart run frameguard doctor
```

## Regions & traces

```dart
FrameGuardRegion(name: 'product_grid', child: ProductGrid());

await FrameGuard.trace('open_product', () async { … });
FrameGuard.mark('products_loaded', metadata: {'count': 42});
await FrameGuard.measureTask('parse_catalog', () => parse(data));
```

## Philosophy

1. Measured facts  
2. Derived classifications  
3. Heuristic suggestions  

Never invent Unavailable metrics as zeros.
