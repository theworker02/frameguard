# Contributing to FrameGuard

Thanks for helping make Flutter performance regressions testable.

## Principles

1. **Measured facts vs classifications vs heuristics** — never mix them in APIs or copy.
2. **No fake metrics** — unavailable signals are `Unavailable`, not `0`.
3. **Low overhead** — the observer must not become the jank.
4. **Local by default** — no telemetry, no required cloud.
5. **Deliberate baselines** — never silently overwrite golden files.
6. **Brand** — follow [branding/BRAND.md](branding/BRAND.md) for user-facing copy.

## Setup

```bash
flutter pub get
dart format .
flutter analyze
flutter test
dart run frameguard version
```

## Pull requests

- Prefer small, focused changes.
- Add/extend tests for analysis engine changes.
- Update `CHANGELOG.md` under `[Unreleased]` (or the next version section).
- Update `doc/diagnostics/` when adding a diagnostic ID.
- Keep the public API surface small.

Use the PR template checklist.

## Commit style

Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`.

## Reporting bugs

See [SUPPORT.md](SUPPORT.md). Include FrameGuard / Flutter versions, build mode, platform, and a redacted report JSON when possible.

## Code of conduct

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
