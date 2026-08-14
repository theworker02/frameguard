# Support

FrameGuard is an open-source project maintained in the open.

## Where to get help

| Need | Where |
|------|--------|
| Bug report | [GitHub Issues](https://github.com/theworker02/frameguard/issues) |
| Feature idea | GitHub Issues with the `enhancement` label |
| Usage question | GitHub Discussions (when enabled) or Issues |
| Security | See [SECURITY.md](SECURITY.md) |
| Diagnostics reference | [doc/diagnostics](doc/diagnostics) |

## Before you open an issue

Please include:

- FrameGuard version (`dart run frameguard version`)
- Flutter / Dart versions (`flutter --version`)
- Build mode (debug / profile / release)
- Platform and approximate refresh rate
- A redacted report JSON when possible

## Scope

FrameGuard does **not** replace Flutter DevTools. Questions about interpreting a one-off Timeline are usually better answered in DevTools docs; FrameGuard issues should focus on budgets, baselines, reports, false positives, and CI integration.
