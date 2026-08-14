# FrameGuard CLI

Local performance regression tooling. No telemetry.

```bash
dart run frameguard help
dart run frameguard <command> --help   # via: dart run frameguard help <command>
```

## Command groups

| Group | Commands |
|-------|----------|
| Setup | `init`, `doctor`, `version`, `config`, `profiles`, `completions`, `migrate` |
| Inspect | `list`, `inspect`, `explain`, `frames`, `regions`, `tasks`, `stats`, `top`, `histogram`, `validate` |
| Gates | `check`, `suggest-budget`, `compare`/`diff`, `merge`, `drift`, `history`, `baseline`, `watch` |
| Export | `report`, `summary`, `export`, `artifacts`, `batch` |

Exit codes: `0` pass · `1` regression · `2` invalid.

### Useful gates

```bash
# Fail CI unless an explicit budget profile is chosen
dart run frameguard check reports/ --require-profile --profile mid_range

# Draft a budget from a healthy capture
dart run frameguard suggest-budget reports/home_scroll.json --format dart

# Append compact trend points (local JSONL, no SaaS)
dart run frameguard check reports/ --record-history
dart run frameguard history drift home_scroll
```

See also: [docs/cli.html](../docs/cli.html), [ci.md](ci.md).
