# ScRDAVis (`scrdavis`)

- **Status:** `pending` -- both platform bundles build and pass smoke; **not** in the
  catalog; the author issue is still to be opened after the user's functional test.
- **Upstream:** https://github.com/GudaLab/ScRDAVis (no `LICENSE` file)
- **Fork:** https://github.com/fentouxungui/ScRDAVis
- **Release:** https://github.com/fentouxungui/ScRDAVis/releases/tag/v1.1.2 (`v1.1.2`)
- **Artifacts:** `scrdavis-1.1.2-win-x64.zip` (1617 MB),
  `scrdavis-1.1.2-mac-arm64.zip` (1535 MB)
- **Template:** pre-hardening personal skill (v3 era), with app-specific patch steps.

## Why it is packaged this way

| Setting | Value | Reason |
|---|---|---|
| platforms | `win-x64`, `mac-arm64` | v1.0.2 was Windows-only; v1.1.2 vendors the XQuartz dylibs so macOS works without XQuartz |
| `EXTRA_PKGS` | 87 declared packages | Seurat / monocle3 / CellChat stack |
| `SOFT_PKGS` | both `BSgenome` references | 1.4 GB combined; with the closure the bundle would exceed the 2 GiB release limit |
| `ARCHIVE_URLS` | 11 GitHub-only packages + BPCells | not on CRAN/Bioconductor; BPCells is the `r/` package inside `bnprks/BPCells` |
| `MACOS_BREW_DEPS` | `openssl@3 hdf5` (inline step) | `alabaster.base` links `-lssl`; `BPCells` needs `pkg-config hdf5`; written into `~/.R/Makevars` |
| `SOURCE_REBUILD` | `gdtools` | rebuild statically so no XQuartz link remains |
| `PATCH` (in workflow) | `global.R`, `scripts/tfrn1.R`, `www/sctype` | remove startup genome installs, add `ensure_bsgenome()` per species, vendor scType for offline use |
| `MAX_REQUEST_MB` | 4096 | single-cell matrices |
| `SMOKE_TIMEOUT_SEC` | 1800 | Seurat/monocle3 first load |

## Debug log

| # | Symptom | Root cause | Fix | Verified by |
|---|---|---|---|---|
| 1 | `monocle3` install failed three rounds | `BPCells` is not at the tarball root (it is `r/` in `bnprks/BPCells`) | detect the single `DESCRIPTION` in the unpacked tarball and install that directory | `installing archived package: BPCells` |
| 2 | BPCells compile failed | its `DESCRIPTION` imports (`readr`, `hexbin`) were not installed first | read the archived package's `DESCRIPTION`, install missing Imports before building | install completes |
| 3 | `leidenbase` missing | GitHub-only dependency of monocle3 | add it to `ARCHIVE_URLS` | closure resolves |
| 4 | macOS blocked at v1.0.2 | `monocle3` -> `ggrastr` -> `Cairo` needs XQuartz | initially Windows-only; solved in v1.1.2 (rows 7-8) | v1.0.2 win only |
| 5 | 1.4 GB genome data cannot ship | two `BSgenome` packages + 484-package closure | drop both from the bundle, disable TF module on start, add user-triggered per-species download | bundle 1.6 GB, smoke OK |
| 6 | TF module unusable offline | `BSgenome` not bundled | `ensure_bsgenome()` installs into `%APPDATA%\ScRDAVis\rlib`, shows progress, 2 h timeout, readable error | manual first-use test |
| 7 | macOS `Cairo.so` links `/opt/X11` | CRAN binary links the X11 client libs | install XQuartz on the runner, copy the referenced dylibs into `Cairo/libs/`, rewrite with `install_name_tool` to `@loader_path`, ad-hoc `codesign`, recurse | audit clean, no XQuartz on the test Mac (v1.1.0) |
| 8 | `alabaster.base` `ld: library 'ssl' not found`; `BPCells` `pkg-config hdf5` failed | Homebrew `openssl@3` is keg-only; hdf5 dev libs absent | `brew install openssl@3 hdf5`, export `PKG_CONFIG_PATH`/`CPPFLAGS`/`LDFLAGS` and write them into `~/.R/Makevars` (R does not reliably pass `LDFLAGS` from the environment) | source builds link (v1.1.1) |
| 9 | BPCells configure still could not find hdf5 | `SOURCE_REBUILD` hides Homebrew and blanks `PKG_CONFIG_PATH`/`PKG_CONFIG_LIBDIR` but restored only `PATH` | save and restore all three variables after the gdtools rebuild | v1.1.2 dual-platform green |
| 10 | Shared-library question after install | the shell moves package dirs into `%APPDATA%\shinyapps\lib` and empties the app's `rlib` | keep downloaded genomes outside the app dir; append the user library; check `requireNamespace()` before downloading; vendored `libs/` move with the package | inspection of a real install (shell 0.1.11) |

## Known limitations

- Windows and macOS both available since v1.1.2; the mac bundle carries vendored XQuartz
  dylibs (+15-30 MB) that users do not install.
- TF motif module needs a one-time download (~700 MB per species) and network on first use.
- Upstream has no license: **do not list until the author explicitly agrees**.
- Shared-library dedup is by package name+version; another app bundling the same `Cairo`
  version without the vendored dylibs could collide. Rare; re-test if it happens.
- `scType` is offline (vendored), but other modules may need network depending on the data source.

## Reuse notes

The monorepo/subdirectory archive handling, the "read the archived DESCRIPTION first"
step, the X11 dylib vendoring recipe, the `openssl@3`/`hdf5` Makevars fix, and the on-demand
user-library pattern are the reusable parts. The app-specific patch steps are tied to
ScRDAVis file names.
