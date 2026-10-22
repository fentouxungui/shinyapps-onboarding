# esquisse (`esquisse`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/dreamRs/esquisse
- **Fork:** https://github.com/fentouxungui/esquisse
- **Release:** https://github.com/fentouxungui/esquisse/releases/tag/v0.1.0 (`v0.1.0`)
- **Artifacts:**
  - `esquisse-0.1.0-win-x64.zip` (113 MB)
  - `esquisse-0.1.0-mac-arm64.zip` (106 MB)
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `auto` |
| `EXTRA_PKGS` | ggthemes,hrbrthemes,plotly |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 0 source tarball(s) |
| `SOURCE_REBUILD` | (none) |

## Known limitations

Packaged as a package-fn app: the entry builds a shinyApp from the exported esquisse_ui()/esquisse_server() module (esquisser() itself only calls shiny::runGadget). Starts with the built-in iris dataset; import your own data via file/copypaste/url. RStudio-only features (insert code into the current script, read the editor selection) are unavailable in the desktop app; viewing and copying the generated code works. plotly (interactive plot) and ggthemes/hrbrthemes (extra themes) are bundled; PowerPoint export is not bundled (its rvg/gdtools dependency links non-portable macOS libraries).

## Debug log

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.