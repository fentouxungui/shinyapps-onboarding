# shiny-genome-stats (`genome-stats`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/MPUSP/shiny-genome-stats
- **Fork:** https://github.com/fentouxungui/shiny-genome-stats
- **Release:** https://github.com/MPUSP/shiny-genome-stats/releases/tag/v1.1.1 (`v1.1.1`)
- **Artifacts:**
  - `genome-stats-1.1.1-win-x64.zip` (216 MB)
  - `genome-stats-1.1.1-mac-arm64.zip` (193 MB)
- **Template:** upstream `.github/workflows/build-app-bundle.yml` at `v1.1.1`; the workflow is a snapshot, not a template.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `auto` |
| `EXTRA_PKGS` | (none) |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 0 source tarball(s) |
| `SOURCE_REBUILD` | (none) |

## Known limitations

Genome summary tables are generated at build time from NCBI (datasets CLI) in a separate job.

## Debug log

- 2026-11-04: upstream `v1.1.1` released (PR #13 merged). Synchronized this
  record and the workflow snapshot from `MPUSP/shiny-genome-stats`; the release
  provides `genome-stats-1.1.1-win-x64.zip` and
  `genome-stats-1.1.1-mac-arm64.zip`.
- 2026-10-22: backfilled from the release assets; no run-by-run history is
  available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.