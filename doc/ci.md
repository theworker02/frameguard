# CI integration

FrameGuard is designed for local and CI enforcement without a hosted service.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Pass |
| 1 | Regression / budget failure |
| 2 | Invalid report or configuration |

## Minimal workflow

```yaml
name: Performance
on: [push, pull_request]
jobs:
  frameguard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - name: Run Flutter performance tests
        run: flutter test integration_test
      - name: Check FrameGuard budgets
        run: dart run frameguard check reports/ --baseline baselines/catalog.json --require-profile --profile mid_range
```

### Composite action

```yaml
- uses: theworker02/frameguard/.github/actions/frameguard-check@main
  with:
    report: reports/
    baseline: baselines/
    profile: mid_range
    require-profile: 'true'
    record-history: 'true'
```

## Tips

- Capture reports in **profile** mode when possible.
- Commit baselines deliberately after review (`baseline update --force`).
- Use `--require-matching-environment` for strict device farms.
- Use `--require-profile` so CI never silently skips budget evaluation.
- Upload `reports/*.json` and HTML artifacts for PR review — still no SaaS required.
- Post a Markdown summary on the PR:

```bash
dart run frameguard summary reports/catalog.json --format markdown >> $GITHUB_STEP_SUMMARY
```

- Run `dart run frameguard doctor` early in the job to catch missing config/baselines.
