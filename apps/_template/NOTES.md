# <Name> (`<id>`)

- **Status:** `<status>` -- <one sentence: built and waiting for the author / listed /
  rejected by the author / withdrawn on request / never built>
- **Upstream:** <upstream-url>
- **Fork:** <fork-url>
- **Release:** <release-url> (`<tag>`)
- **Artifacts:** one entry per platform listed in `meta.yml`, e.g.
  `<id>-<version>-win-x64.zip` (<N> MB)
- **Template:** <template version>; deviations are listed in `meta.yml` and below.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.** Keep the
> workflow only as a packaging reference.

## Why it is packaged this way

| Setting | Value | Reason |
|---|---|---|
| `APP_MODE` | | |
| `EXTRA_PKGS` | | |
| `SOFT_PKGS` | | |
| `ARCHIVE_URLS` | | |
| `SOURCE_REBUILD` | | |

## Debug log

One row per failed run: symptom in the log -> root cause -> fix -> how it was verified.

| # | Symptom (log line) | Root cause | Fix | Verified by |
|---|---|---|---|---|
| 1 | | | | |

## Known limitations

- <module/feature that is disabled, and where it is recorded (APP_NOTES, PR/issue)>

## Reuse notes

What to copy for a similar app, and what is specific to this one.
