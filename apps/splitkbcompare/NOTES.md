# splitKbCompare (`splitkbcompare`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/jhelvy/splitKbCompare
- **Fork:** https://github.com/fentouxungui/splitKbCompare
- **Release:** https://github.com/fentouxungui/splitKbCompare/releases/tag/v0.1.0 (`v0.1.0`)
- **Artifacts:**
  - `splitkbcompare-0.1.0-win-x64.zip` (90 MB)
  - `splitkbcompare-0.1.0-mac-arm64.zip` (78 MB)
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `auto` |
| `EXTRA_PKGS` | rmarkdown |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 0 source tarball(s) |
| `SOURCE_REBUILD` | (none) |

## Known limitations

Classic ui.R/server.R app wrapped by a generated app/app.R (sources global.R/ui.R/server.R and returns shinyApp). KNOWN LIMITATION: the dynamic Print-to-scale (PDF) button uses rmarkdown::render(pdf_document) and needs a LaTeX engine absent from the desktop bundle; the 62 pre-generated per-keyboard PDFs still work offline. Ships images/png + images/pdf only (raw/ and .ai sources excluded).

## Debug log

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.