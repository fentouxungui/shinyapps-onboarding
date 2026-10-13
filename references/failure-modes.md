# Failure modes seen in practice, and their fixes

Every item below comes from a real ShinyApps onboarding. The workflow already handles most
of them; the rest need a decision you make during feasibility.

## Build-time

1. **`git clone`/`fetch` hangs or aborts.** A global git-lfs `filter.*` config on some
   machines. Disable per command:
   `-c filter.lfs.process= -c filter.lfs.smudge= -c filter.lfs.clean= -c filter.lfs.required=false`.
2. **`missing required dependencies: methods, stats, utils`.** Base-priority packages were
   wrongly treated as required. Always exclude `installed.packages(priority="base")`.
3. **Bioconductor annotation/data packages not installed** (`org.*.eg.db`, `TxDb.*`,
   `GO.db`, `reactome.db`). They have **no binaries** for a brand-new R. Use
   `pkgType="both"` so R falls back to **source** (they are pure R -- no compiler needed).
4. **A transitive dependency silently missing** (e.g. `fgsea` pulled in via
   `ReactomePA -> enrichplot -> fgsea`). The dependency graph built from the **binary**
   index drops edges on a new R. Build it from the **source** index
   (`available.packages(type="source")`) and add a **fix-up loop**: re-read installed
   `DESCRIPTION`s and install whatever is still missing, until convergence.
5. **"Builds but won't start."** Validate at build end that every required seed package can
   be **loaded from `rlib/`** (`requireNamespace(pkg, lib.loc=lib)`); fail otherwise.
6. **macOS: bundle won't launch / dylib errors.** Some CRAN macOS binaries hard-link
   XQuartz / Homebrew (`/opt/X11`, `/opt/homebrew`, `/usr/local/opt`). Rebuild those
   packages from source (`SOURCE_REBUILD`) and audit `rlib/**/*.so|*.dylib` with
   `otool -L`; fail on non-portable references.
7. **CRAN-archived package** (`geomnet` 2021, `RSVGTipsDevice` 2016, ...). Install it from
   its **CRAN Archive** tarball (`ARCHIVE_URLS`); if it won't compile, ship a minimal
   **stub** for the missing function.
8. **`R CMD INSTALL` says `dependency 'X' is not available`.** R CMD INSTALL requires
   `Imports` to be present. Install the closure -- **or** don't install the package at all
   when it is not needed at runtime (see package-deploy).
9. **Huge closure / Release asset > 2 GiB.** Trim optional modules, drop dev-only packages
   (`devtools`, `usethis`, runtime `install_*.R` bootstraps), and `EXCLUDE` large source
   assets (`.ai`/SVG/raw/ screenshots). The workflow size-guards the asset.

## Runtime (after install)

10. **`object 'PKG' not found` / the entry function calls `runApp()` and the app reads
    package internals.** Do **not** use `library(pkg)` + `pkg:::` + `shinyAppDir` from the
    bundle. Use the flat-directory copy, or the package-deploy recipe. See
    `references/app-shapes.md`.
11. **App errors at startup from old Shiny idioms.** e.g. `attr(input,"readonly") <- FALSE`,
    `max(NULL)` when inputs are unset, `input$x[1] <- ...`. Modern Shiny changed
    `reactivevalues`. Reproduce with the **same** `shiny` + app versions, then fix the app
    code (guard with `req()`, use `reactiveVal()`), or disclose.
12. **A fix shipped under the SAME version tag is never installed.** The client compares the
    catalog version to the installed one. **Always bump the version** (`vX.Y.Z`) for any
    change; re-pushing the same tag produces no `Update`. Delete/reinstall locally to test.
13. **Runtime engine/service needed** (Enrichr/KEGG network, a remote service, LaTeX for a
    dynamic PDF, Windows HDF5 via `hdf5r`). Disclose it in `APP_NOTES` and the PR; it may
    work partially or only with network.

## Ops

14. **The app never appears in the store.** `publish-catalog` discovers assets by the
    **`<id>-<version>-<platform>.zip`** filename from the repo's **latest Release**. A
    wrong `id`, wrong filename, or no published Release = no catalog entry.
15. **Verify, always.** Read back `https://<owner>.github.io/ShinyApps/catalog.json` and
    confirm the app's `version`, both platform artifacts, and their `sha256`.
