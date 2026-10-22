# GateLabR (`gatelabr`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/david-priest/GateLabR
- **Fork:** https://github.com/fentouxungui/GateLabR
- **Release:** https://github.com/fentouxungui/GateLabR/releases/tag/v0.2.1 (`v0.2.1`)
- **Artifacts:**
  - `gatelabr-0.2.1-win-x64.zip` (150 MB)
  - `gatelabr-0.2.1-mac-arm64.zip` (164 MB)
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `flat` |
| `EXTRA_PKGS` | shiny,DT,digest,future,jsonlite,later,nnls,promises,rlang,base64enc,uuid,sp,png,gridSVG,ggplot2,MASS,SingleCellExperiment,SummarizedExperiment,S4Vectors,flowCore,stringi,xml2 |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 1 source tarball(s) |
| `SOURCE_REBUILD` | (none) |

## Known limitations

Entry builds the GateLabR app object from a synthetic demo SingleCellExperiment; ships no real cytometry data.

## Debug log

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.