# ScRDAVis (`scrdavis`)

- **Status:** `pending` -- Windows bundle builds and passes smoke; **not** in the catalog;
  the author issue is still to be opened after the user's functional test.
- **Upstream:** https://github.com/GudaLab/ScRDAVis (no `LICENSE` file)
- **Fork:** https://github.com/fentouxungui/ScRDAVis
- **Release:** https://github.com/fentouxungui/ScRDAVis/releases/tag/v1.0.2 (`v1.0.2`)
- **Artifacts:** `scrdavis-1.0.2-win-x64.zip` (1.70 GB / 1.58 GiB). No macOS artifact.
- **Template:** pre-hardening personal skill (v3 era), with app-specific patch steps.

## Why it is packaged this way

| Setting | Value | Reason |
|---|---|---|
| platforms | `win-x64` only | `monocle3` imports `ggrastr` -> `Cairo`; CRAN's macOS binary needs XQuartz and cannot be vendored reliably |
| `EXTRA_PKGS` | 87 declared packages | Seurat / monocle3 / CellChat stack |
| `SOFT_PKGS` | both `BSgenome` references | 1.4 GB combined; with the closure the bundle would exceed the 2 GiB release limit |
| `ARCHIVE_URLS` | 11 GitHub-only packages + BPCells | not on CRAN/Bioconductor; BPCells is the `r/` package inside `bnprks/BPCells` |
| `PATCH` (in workflow) | `global.R`, `scripts/tfrn1.R`, `www/sctype` | remove startup genome installs, add `ensure_bsgenome()` per species, vendor scType for offline use |
| `MAX_REQUEST_MB` | 4096 | single-cell matrices |
| `SMOKE_TIMEOUT_SEC` | 1800 | Seurat/monocle3 first load |

## Debug log

| # | Symptom | Root cause | Fix | Verified by |
|---|---|---|---|---|
| 1 | `monocle3` install failed three rounds | `BPCells` is not at the tarball root (it is `r/` in `bnprks/BPCells`) | detect the single `DESCRIPTION` in the unpacked tarball and install that directory | `installing archived package: BPCells` |
| 2 | BPCells compile failed | its `DESCRIPTION` imports (`readr`, `hexbin`) were not installed first | read the archived package's `DESCRIPTION`, install missing Imports before building | install completes |
| 3 | `leidenbase` missing | GitHub-only dependency of monocle3 | add it to `ARCHIVE_URLS` | closure resolves |
| 4 | macOS build blocked | `monocle3` -> `ggrastr` -> `Cairo` needs XQuartz | publish Windows-only (`v1.0.1`, then `v1.0.2`) | win build green |
| 5 | 1.4 GB genome data cannot ship | two `BSgenome` packages + 484-package closure | drop both from the bundle, disable TF module on start, add user-triggered per-species download | bundle 1.62 GB, smoke OK |
| 6 | TF module unusable offline | `BSgenome` not bundled | `ensure_bsgenome()` installs into `%APPDATA%\ScRDAVis\rlib`, shows progress, 2 h timeout, readable error | manual first-use test |

## Known limitations

- Windows-only; macOS has no artifact.
- TF motif module needs a one-time download (~700 MB per species) and network on first use.
- Upstream has no license: **do not list until the author explicitly agrees**.
- `scType` is offline (vendored), but other modules may need network depending on the data source.

## Reuse notes

The monorepo/subdirectory archive handling, the "read the archived DESCRIPTION first"
step, and the on-demand user-library pattern are the reusable parts. The app-specific
patch steps are tied to ScRDAVis file names.
