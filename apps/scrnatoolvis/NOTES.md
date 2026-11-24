# scRNAtoolVis (`scrnatoolvis`)

- **Status:** `active` -- both platform bundles are published on the `v0.1.1` release and the app is
  listed in `ShinyApps/catalog/apps.yml` (record corrected from `pending` on 2026-11-24).
- **Upstream:** https://github.com/fentouxungui/scRNAtoolVis
- **Fork:** https://github.com/fentouxungui/scRNAtoolVis
- **Release:** https://github.com/fentouxungui/scRNAtoolVis/releases/tag/v0.1.1 (`v0.1.1`)
- **Artifacts:** `scrnatoolvis-0.1.1-win-x64-r4.6.zip` (307 MB),
  `scrnatoolvis-0.1.1-mac-arm64-r4.6.zip` (360 MB), both uploaded 2026-11-17.
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
| `MACOS_BREW_DEPS` | (none) |

The app lives under `inst/shinyapp` but calls `scRNAtoolVis` functions and reads
its shipped `extdata`/`data`. A flat copy alone would fail at
`requireNamespace("scRNAtoolVis")`; the workflow therefore installs the package
from the pinned tag archive and then runs the copied app directory.

## Known limitations

- **macOS was deferred, now shipped.** `ggunchull` failed to install on `macos-14` at
  v0.1.1 time; the release nevertheless carries `scrnatoolvis-0.1.1-mac-arm64-r4.6.zip`
  (uploaded 2026-11-17), and `meta.yml` now claims `win-x64, mac-arm64`.
- **Legacy `.qs` uploads are not supported.** `qs` is archived on CRAN; the app
  uses `qs2` and accepts `.rds` / `.qs2`. Users can convert legacy `.qs` files
  with `qs` and re-save as `.rds` or `.qs2`.
- **Release assets published.** `v0.1.1` carries both platform zips, which is what
  `publish-catalog` needs; the earlier "CI artifact only, no release asset" state is resolved.
- The bundle includes GPL-3.0-or-later `ggunchull` and `qs2`.

## Debug log

- 2026-10-30: Windows bundle built successfully in run `41012187469`.
- 2026-10-30: macOS build failed while installing `ggunchull`; workflow reduced
  to a Windows-only matrix and declared the deferral in `APP_NOTES`.
- 2026-11-17: both `win-x64` and `mac-arm64` bundles uploaded to the `v0.1.1` release.

## Reuse notes

Use the workflow and `meta.yml` decisions as a reference for another
package-backed flat app with GitHub-only dependencies. Re-run the dependency
census, and check the release assets rather than the record before claiming a platform:
the macOS deferral here was resolved without the record being updated.
