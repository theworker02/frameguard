# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-08-13

### Added

- Local history store (`FrameGuardHistory` / JSONL) with CLI
  `history append|show|list|drift|clear`
- `BudgetSuggestion` + CLI `suggest-budget` (draft budgets from measured reports)
- `check --require-profile` and `check --record-history`
- Reusable GitHub Action composite: `.github/actions/frameguard-check`
- Explanation JSON round-trip (`ScenarioExplanation.fromJson` + report decode)
- `tool/sync_version.dart --check` for CI version drift detection
- Site polish: `robots.txt`, `sitemap.xml`, `404.html`
- `CITATION.cff`, `NOTICE`, `.editorconfig`, `.gitattributes`
- `init` scaffolds `history/`

### Fixed

- Healthy reports no longer mislabeled as “Excessive build work”
- `hasJankRateBelow` treats the limit as inclusive (`<=`)
- `.gitignore` no longer excludes GitHub Pages HTML under `docs/`
- pub.dev topics trimmed to the 5-topic limit

### Changed

- Package version `0.5.0` → `0.6.0`
- CLI `migrate` re-encodes report metadata to the current package version

## [0.5.0] - 2026-08-13

### Added

- Expansive CLI rewrite (`lib/src/cli/`) with command catalog:
  `help`, `list`/`ls`, `explain`, `frames`, `regions`, `tasks`, `stats`,
  `top`, `histogram`, `validate`, `drift`, `profiles`, `artifacts`, `batch`,
  `watch`, `completions`, `diff` (compare alias), richer `baseline` /
  `config` / `check` / `merge` options
- `StatisticalSummary.toJson`

### Changed

- Package version `0.4.0` → `0.5.0`
- `bin/frameguard.dart` is a thin entrypoint over `runFrameGuardCli`

## [0.4.0] - 2026-08-13

### Added

- GitHub Pages product site under `docs/` (guide, CLI, diagnostics, brand)
- Pages deploy workflow (`.github/workflows/pages.yml`)
- Funding: GitHub Sponsors + thanks.dev (`u/gh/theworker02`)
- Brand tokens (`branding/tokens.css`), favicon, expanded brand kit
- `FrameGuardReport.writeMarkdown` / `writeArtifacts`
- CLI `init` + `FrameGuardInit` scaffolding helper

### Changed

- Repository / docs URLs point at `theworker02/frameguard` and Pages
- Package version `0.3.0` → `0.4.0`

## [0.3.0] - 2026-08-13

### Added

- `FrameGuard.runSession` convenience API (start → body → stop)
- Markdown / PR-comment exporter (`ReportExportFormat.markdown`, CLI `summary`)
- `FrameGuardDoctor` + CLI `doctor` for local setup checks
- Built-in `BudgetProfile.animation60` and `BudgetProfile.byName`
- Branded HTML report theme (ink / signal / pass tokens)
- API cookbook (`doc/api.md`)
- Committed CLI fixtures under `test/fixtures/` + CLI smoke tests
- `tool/sync_version.dart` to keep package version single-sourced
- CI steps for version sync, doctor, and fixture-based CLI checks

### Fixed

- `FrameGuardGolden` CLI hints now point at `baseline update <report.json>`

### Changed

- Package version `0.2.0` → `0.3.0`
- Example app writes session JSON under `reports/` for CLI workflows

## [0.2.0] - 2026-08-12

### Added

- Branding kit (`branding/` SVG+PNG, `BRAND.md`), pub.dev screenshots
- Expanded README with badges, feature map, and brand assets
- Community packaging: CoC, Security, Support, AUTHORS, issue/PR templates,
  Dependabot, FUNDING/CODEOWNERS stubs
- `doc/` guides (CI, scenarios, publishing) — pub layout convention
- Optional `frameguard.yaml` loader (`FrameGuardConfigLoader`) — Dart config remains primary
- `FrameScenarioRunner` for single- and multi-run scenario orchestration
- `StatisticalSummary` / `StatisticalRegression` (median, MAD, trimmed mean, CI, outlier flags)
- Report exporters: CSV, JUnit XML, SARIF (scenario-level, no fake line attribution)
- Platform adapter registry (`Android` / `iOS` / `Web` / default) with honest Unavailable native metrics
- Memory pressure probe hooks (`MemoryProbe`, `MemoryPressureTracker`) — no fabricated GC pauses
- `FrameGuardBudgetWatcher` for local runtime budget violations
- `Stabilization` helper (consecutive healthy frames via public scheduler APIs)
- CLI `export` command (`--format csv|junit|sarif|html|json|text`)

### Changed

- Package version `0.1.0` → `0.2.0`

## [0.1.0] - 2026-08-12

### Added

- Initial FrameGuard release: sessions, budgets, baselines, reports, matchers, CLI
