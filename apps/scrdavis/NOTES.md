# ScRDAVis (`scrdavis`)

- **Status:** `active` -- both platform bundles built and passed smoke, and the app is
  listed in `ShinyApps/catalog/apps.yml` (which is the source of truth for listing;
  the record's `status` was corrected from `pending` on 2026-11-24).
- **Upstream:** https://github.com/GudaLab/ScRDAVis (no `LICENSE` file)
- **Fork:** https://github.com/fentouxungui/ScRDAVis
- **Release:** https://github.com/fentouxungui/ScRDAVis/releases/tag/v1.1.2 (`v1.1.2`)
- **Artifacts:** `scrdavis-1.1.2-win-x64.zip` (1617 MB),
  `scrdavis-1.1.2-mac-arm64.zip` (1535 MB)
- **Template:** pre-hardening personal skill (v3 era) for v1.1.2; local v1.1.3
  rebuild uses the standard `build-app-bundle.yml` from skill `2026.11.18.2`.

## Why it is packaged this way

| Setting | Value | Reason |
|---|---|---|
| platforms | `win-x64`, `mac-arm64` | v1.0.2 was Windows-only; v1.1.2 vendors the XQuartz dylibs so macOS works without XQuartz |
| `EXTRA_PKGS` | 86 declared packages | Seurat / monocle3 / CellChat stack; the v1.1.3 Windows asset predates dropping devtools, the mac rebuild uses 86 |
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
| 11 | GitHub rejected the workflow: `Exceeded max expression length 21000` at `Assemble bundle` | the 24.6k-character `run:` block contained `${{ matrix.platform }}`; GitHub evaluates the whole block as one expression | pass `BUNDLE_PLATFORM` through `env:` and read `Sys.getenv("BUNDLE_PLATFORM")` in both assemble and zip scripts | static: no remaining `${{ }}` in the >21k blocks; v1.1.3 CI pending |
| 12 | `ARCHIVE_URLS: expected one package DESCRIPTION inside main, found 2` | BPCells now has a root sentinel `DESCRIPTION` (`BPCells.installation.moved`) plus the real `r/DESCRIPTION` (`Package: BPCells`) | read every candidate `Package` and select the one in `FORCED_PKGS`; error lists candidates if the match is ambiguous | static: BPCells candidates are the root sentinel and `r/BPCells`; v1.1.3 CI pending |
| 13 | mac-arm64 job `cancelled` with no steps: `The job was not acquired by Runner of type hosted` / `Internal server error` | GitHub-hosted macOS capacity or transient runner-service failure; no runner was assigned | retry later; use a manual Build Bundle dispatch with `tag=v1.1.3`, `platforms=mac-arm64` so only the mac zip attaches to the existing Release; do not re-run all jobs | Release v1.1.3 currently has only `scrdavis-1.1.3-win-x64-r4.6.zip`; mac retry pending |
| 14 | macOS audit: 15 files under `rlib/pak/library` reference `/Library/Frameworks/R.framework` | `devtools` (in `EXTRA_PKGS`) imports `pak`; pak's private library is not rewritten by portable R's `.portable` patcher | remove unused `devtools` from `EXTRA_PKGS` and delete its startup `require` in `global.R`; no other app package imports pak | static: `devtools`/`pak` no longer in seed; v1.1.3 mac CI pending |

## Known limitations

- Windows and macOS both available since v1.1.2; the mac bundle carries vendored XQuartz
  dylibs (+15-30 MB) that users do not install.
- TF motif module needs a one-time download (~700 MB per species) and network on first use.
- Upstream has no license: **do not list until the author explicitly agrees**.
- Shared-library dedup is by package name+version; another app bundling the same `Cairo`
  version without the vendored dylibs could collide. **v1.1.2 predates the unique-suffix
  rule and shipped Cairo unpatched.** Suffix `9001` is reserved in
  `apps/pkg-versions.tsv`; the next rebuild must set `PKG_VERSION_PACKAGES: "Cairo"` and
  `PKG_VERSION_SUFFIX: "9001"` so this bundle cannot be merged with another app's Cairo.
  Until then, do not give another Cairo-vendoring app suffix 9001 (use the allocator).
- `scType` is offline (vendored), but other modules may need network depending on the data source.

## Reuse notes

The monorepo/subdirectory archive handling, the "read the archived DESCRIPTION first"
step, the X11 dylib vendoring recipe, the `openssl@3`/`hdf5` Makevars fix, and the on-demand
user-library pattern are the reusable parts. The app-specific patch steps are tied to
ScRDAVis file names.
