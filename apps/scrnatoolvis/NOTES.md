# scRNAtoolVis (`scrnatoolvis`)

- **Status:** `pending` -- the Windows bundle builds in CI, but the catalog still needs a GitHub Release asset.
- **Upstream:** https://github.com/fentouxungui/scRNAtoolVis
- **Fork:** https://github.com/fentouxungui/scRNAtoolVis
- **Release:** https://github.com/fentouxungui/scRNAtoolVis/releases/tag/v0.1.1 (`v0.1.1`)
- **CI run:** https://github.com/fentouxungui/scRNAtoolVis/actions/runs/41012187469 (win-x64 artifact, 338,828,277 bytes)
- **Template:** hardened v3 -- flat app + pinned GitHub archive dependencies.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `flat` |
| `APP_SUBDIR` | `inst/shinyapp` |
| `EXTRA_PKGS` | `scRNAtoolVis qs2` |
| `SOFT_PKGS` | `jjAnno jjPlot ggunchull scRNAtoolVis` |
| `ARCHIVE_URLS` | 4 pinned tarballs: jjAnno, jjPlot, ggunchull, scRNAtoolVis v0.1.1 |
| `FORCED_PKGS` | `jjAnno jjPlot ggunchull scRNAtoolVis` |
| `SOURCE_REBUILD` | (none) |
| `MACOS_BREW_DEPS` | (none; Windows-only build) |

The app lives under `inst/shinyapp` but calls `scRNAtoolVis` functions and reads
its shipped `extdata`/`data`. A flat copy alone would fail at
`requireNamespace("scRNAtoolVis")`; the workflow therefore installs the package
from the pinned tag archive and then runs the copied app directory.

## Known limitations

- **macOS is deferred.** The `ggunchull` dependency chain fails while installing
  on `macos-14`. The current workflow intentionally publishes `win-x64` only;
  the `mac-arm64` asset is not claimed.
- **Legacy `.qs` uploads are not supported.** `qs` is archived on CRAN; the app
  uses `qs2` and accepts `.rds` / `.qs2`. Users can convert legacy `.qs` files
  with `qs` and re-save as `.rds` or `.qs2`.
- **Release asset pending.** The v0.1.1 release currently has no bundle asset;
  a successful CI artifact is not sufficient for `publish-catalog`.
- The bundle includes GPL-3.0-or-later `ggunchull` and `qs2`.

## Debug log

- 2026-10-30: Windows bundle built successfully in run `41012187469`.
- 2026-10-30: macOS build failed while installing `ggunchull`; workflow reduced
  to a Windows-only matrix and declared the deferral in `APP_NOTES`.

## Reuse notes

Use the workflow and `meta.yml` decisions as a reference for another
package-backed flat app with GitHub-only dependencies. Re-run the dependency
census and re-verify the macOS deferral before adding mac-arm64.
