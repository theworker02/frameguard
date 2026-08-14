# Scenario tooling

`FrameScenario` + `FrameScenarioRunner` make performance scenarios reusable across commits.

```dart
final runner = FrameScenarioRunner(
  scenario: const FrameScenario(
    name: 'catalog_scroll',
    warmup: Duration(seconds: 1),
    warmupFrames: 30,
  ),
  runs: 5,
  budget: FrameBudget.forRefreshRate(120),
  minSampleCount: 30,
);

final result = await runner.runAggregated((run) async {
  await scrollCatalog();
});

print(result.summary());
// Includes aggregate + statistical summary (median, MAD, CI, outlier flags).
```

Compare two multi-run campaigns:

```dart
final regression = StatisticalRegression(minRuns: 3).compare(
  baseline: baselineSummary,
  current: currentSummary,
  scenario: 'catalog_scroll',
);
if (regression.isRegression) {
  fail(regression.message);
}
```

Outliers are **flagged**, never deleted. Raw worst frames stay in each report.
