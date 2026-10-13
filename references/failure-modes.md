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
5. **A dependency is installed but the package still won't load.** `loadNamespace()` resolves a
   package's own imports via `.libPaths()`, so add the bundle's `rlib/` to it before install and
   validation (`.libPaths(c(lib, .libPaths()))`); otherwise `requireNamespace(pkg, lib.loc=lib)`
   can fail even though every dependency is present in `rlib/`. Surface the real error when
   validation fails (`loadNamespace` in a `tryCatch`) instead of returning a bare `FALSE`.
6. **"Builds but won't start."** Validate at build end that every required seed package can
   be **loaded from `rlib/`** (`requireNamespace(pkg, lib.loc=lib)`); fail otherwise.
7. **macOS: bundle won't launch / dylib errors.** Some CRAN macOS binaries hard-link
   XQuartz / Homebrew (`/opt/X11`, `/opt/homebrew`, `/usr/local/opt`) -- e.g. `gdtools` (pulled by
   `rvg`/`ggiraph`). Either rebuild those packages from source (`SOURCE_REBUILD`) or, simpler, drop the
   optional package that pulls them in and audit `rlib/**/*.so|*.dylib` with
   `otool -L`; fail on non-portable references.
8. **CRAN-archived package** (`geomnet` 2021, `RSVGTipsDevice` 2016, ...). Install it from
   its **CRAN Archive** tarball (`ARCHIVE_URLS`); if it won't compile, ship a minimal
   **stub** for the missing function.
9. **`R CMD INSTALL` says `dependency 'X' is not available`.** R CMD INSTALL requires
   `Imports` to be present. Install the closure -- **or** don't install the package at all
   when it is not needed at runtime (see package-deploy).
10. **Huge closure / Release asset > 2 GiB.** Trim optional modules, drop dev-only packages
   (`devtools`, `usethis`, runtime `install_*.R` bootstraps), and `EXCLUDE` large source
   assets (`.ai`/SVG/raw/ screenshots). The workflow size-guards the asset.

## Runtime (after install)

11. **`object 'PKG' not found` / the entry function calls `runApp()` and the app reads
    package internals.** Do **not** use `library(pkg)` + `pkg:::` + `shinyAppDir` from the
    bundle. Use the flat-directory copy, or the package-deploy recipe. See
    `references/app-shapes.md`.
12. **App errors at startup from old Shiny idioms.** e.g. `attr(input,"readonly") <- FALSE`,
    `max(NULL)` when inputs are unset, `input$x[1] <- ...`. Modern Shiny changed
    `reactivevalues`. Reproduce with the **same** `shiny` + app versions, then fix the app
    code (guard with `req()`, use `reactiveVal()`), or disclose.
13. **A fix shipped under the SAME version tag is never installed.** The client compares the
    catalog version to the installed one. **Always bump the version** (`vX.Y.Z`) for any
    change; re-pushing the same tag produces no `Update`. Delete/reinstall locally to test.
14. **Runtime engine/service needed** (Enrichr/KEGG network, a remote service, LaTeX for a
    dynamic PDF, Windows HDF5 via `hdf5r`). Disclose it in `APP_NOTES` and the PR; it may
    work partially or only with network.

**`golem` apps: `run_app()` returns the app object, but external backends must be disabled.**
   A golem `run_app()` returns `with_golem_options(shinyApp(app_ui, app_server), ...)` without
   calling `runApp()`, so it is a valid package-fn entry. Pass the golem options that turn off
   server-side backends (e.g. `with_mongo = FALSE`), and check that the corresponding tab is
   guarded by `get_golem_options(...)`.

**The target is a framework or a generator, not an app.** `teal` (`init()` returns a list, run
   as `shinyApp(app$ui, app$server)` and needs modules), `learnr` (tutorial framework;
   `run_tutorial()`), and `ShinyCell`/`ShinyCell2` (`makeShinyApp()` writes an app dir from data)
   have **no single runnable app**. Bundle a concrete demo/tutorial app around them instead of
   the framework itself -- see `references/app-shapes.md`.

**Seed extraction picks up regex false positives.** The `pkg::` scan can capture non-package
   tokens (e.g. `digit`, `input`, `BiocInstaller`). Drop seed names that are not in
   `available.packages()` (the template does this, with a `WARN dropped` line) instead of failing.
   Real archived packages are dropped too and must be installed via `ARCHIVE_URLS`.

**An archived dependency (e.g. `pca3d`).** Install it from its CRAN-Archive tarball
   (`ARCHIVE_URLS`). Its install-time dependencies must already be present: add them to
   `EXTRA_PKGS` (e.g. `rgl`, `ellipse` for `pca3d`). The fix-up loop then closes the rest.

**A graphics library whose macOS binary cannot be made portable.** `gdtools` can be rebuilt from
   source (it bundles static cairo via `autobrew`), but **`Cairo` cannot** -- its source build
   needs cairo headers, and hiding Homebrew breaks its configure. Apps that hard-require `Cairo`
   (e.g. VEGDESK) cannot currently be shipped portably on macOS; defer them or accept an XQuartz
   dependency on the user's Mac.

**Default branch varies.** Push the workflow to the fork's **default branch** and open the PR
   against the same branch -- repos use `master`, `main`, and sometimes `devel` (e.g. PhyloProfile).

## Ops

15. **Fork names preserve the original case** (e.g. `fentouxungui/PlotsOfData`, not
    `plotsofdata`) and old-name remotes redirect. Use the exact fork name in the catalog `repo`;
    keep the lowercase `<id>` for the asset prefix and catalog id.
16. **The app never appears in the store.** `publish-catalog` discovers assets by the
    **`<id>-<version>-<platform>.zip`** filename from the repo's **latest Release**. A
    wrong `id`, wrong filename, or no published Release = no catalog entry.
17. **Verify, always.** Read back `https://<owner>.github.io/ShinyApps/catalog.json` and
    confirm the app's `version`, both platform artifacts, and their `sha256`.
