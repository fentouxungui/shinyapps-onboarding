# shiny-genome-stats (`genome-stats`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/MPUSP/shiny-genome-stats
- **Fork:** https://github.com/fentouxungui/shiny-genome-stats
- **Release:** https://github.com/fentouxungui/shiny-genome-stats/releases/tag/v0.1.7 (`v0.1.7`)
- **Artifacts:**
  - `genome-stats-0.1.7-win-x64.zip` (216 MB)
  - `genome-stats-0.1.7-mac-arm64.zip` (193 MB)
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

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

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.