# explor (`explor`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/juba/explor
- **Fork:** https://github.com/fentouxungui/explor
- **Release:** https://github.com/fentouxungui/explor/releases/tag/v0.1.2 (`v0.1.2`)
- **Artifacts:**
  - `explor-0.1.2-win-x64.zip` (146 MB)
  - `explor-0.1.2-mac-arm64.zip` (141 MB)
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `auto` |
| `EXTRA_PKGS` | FactoMineR |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 0 source tarball(s) |
| `SOURCE_REBUILD` | (none) |

## Known limitations

package-fn: opens a demo PCA of the built-in iris dataset. explor() dispatches on the analysis object and returns the shiny app object.

## Debug log

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.