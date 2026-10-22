# PlotsOfData (`plotsofdata`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/JoachimGoedhart/PlotsOfData
- **Fork:** https://github.com/fentouxungui/PlotsOfData
- **Release:** https://github.com/fentouxungui/PlotsOfData/releases/tag/v0.1.0 (`v0.1.0`)
- **Artifacts:**
  - `plotsofdata-0.1.0-win-x64.zip` (129 MB)
  - `plotsofdata-0.1.0-mac-arm64.zip` (114 MB)
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

Single-file Shiny app (app.R + themes.R + www/). Import your own data via the app. Some import helpers rely on network/RCurl.

## Debug log

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.