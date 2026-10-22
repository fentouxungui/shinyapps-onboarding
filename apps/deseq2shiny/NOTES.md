# deseq2shiny (`deseq2shiny`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/nasqar/deseq2shiny
- **Fork:** https://github.com/fentouxungui/deseq2shiny
- **Release:** https://github.com/fentouxungui/deseq2shiny/releases/tag/v0.1.3 (`v0.1.3`)
- **Artifacts:**
  - `deseq2shiny-0.1.3-win-x64.zip` (247 MB)
  - `deseq2shiny-0.1.3-mac-arm64.zip` (236 MB)
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `auto` |
| `EXTRA_PKGS` | V8,markdown |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 0 source tarball(s) |
| `SOURCE_REBUILD` | (none) |

## Known limitations

Multi-file Shiny app; ui.R patched so extendShinyjs() passes its custom JS function names (modern shinyjs requires functions=), with V8 and markdown (needed by shiny::includeMarkdown) bundled. Upstream declares no license.

## Debug log

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.