# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.6.x   | Yes |
| 0.5.x   | Best effort |
| < 0.5   | No |

## Reporting a vulnerability

FrameGuard is a **local** diagnostics toolkit. It does not phone home. Still, if you find a security issue in:

- report parsing / CLI file handling
- path traversal in export/baseline commands
- unsafe deserialization assumptions

please **do not** open a public issue.

Prefer:

1. GitHub **Security Advisory** on the repository, or
2. Email the maintainers listed in the repository profile (when published)

Include:

- FrameGuard version
- Flutter / Dart versions
- Steps to reproduce
- Impact assessment

We aim to acknowledge within 7 days.

## Non-goals

FrameGuard intentionally collects performance metadata (frame timings, region names you choose, device class info). Do not put secrets in marker metadata or custom metrics.
