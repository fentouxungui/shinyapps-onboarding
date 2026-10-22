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
11. **Subtracting the whole `installed.packages()` set drops toolchain packages.** A workflow
   that does `setdiff(closure, rownames(installed.packages()))` also removes packages that are
   merely present in the **CI toolchain** (`jsonlite`, `zip`, `digest`, `BiocManager`, `callr`,
   `curl`) even when the app needs them at runtime → `there is no package called 'X'` after install.
   Exclude only **base/recommended** (`installed.packages(priority = "base")`), never all of
   `installed.packages()`. The current `assets/build-app-bundle.yml` already does this; re-onboard
   any app still built with an older per-app workflow (its bundle is missing those packages).

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

**The app downloads a database at first launch and the download times out.** PhyloProfile's
`server.R` calls `processNcbiTaxonomy()` on first run, which `download.file()`s the full NCBI
`taxdmp.zip` (~76 MB). On the desktop bundle this hits R's default 60 s timeout and aborts
mid-stream (`Timeout of 60 seconds was reached`, `downloaded length 6839603 != reported length
79832129`), so the app errors at startup. The step is guarded by a `file.exists("data/<db>")`
check, so do **not** patch the app: pre-generate the file at build time and ship it in the
bundle's `app/` (see `references/startup-data.md`; PhyloProfile generates it once in a dedicated
ubuntu job and copies it into `app/data/preProcessedTaxonomy.txt` before zipping).

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

**Old `shinyjs::extendShinyjs(script = ...)` breaks on modern shinyjs.** The modern API requires
   the `functions=` argument (the JS function names to expose) and the **`V8`** package. Symptom:
   the app returns HTTP 500 / fails to load with `shinyjs: extendShinyjs: 'functions' argument must
   be provided`. Fix the app's `ui.R` (`extendShinyjs(script = "www/custom.js", functions =
   c("fn1", "fn2"))`, names from the JS file) and add `V8` to `EXTRA_PKGS`.

**Indirect dependencies the seed extraction misses.** Some packages are needed at load without a
   `library()`/`pkg::` of their own -- e.g. `shiny::includeMarkdown()` needs the **`markdown`**
   package. The build's seed-based load check passes, but the app errors at runtime with
   `there is no package called 'X'`. Add `X` to `EXTRA_PKGS` (the smoke test points right at it).

**The smoke test is the safety net for exactly these.** The build-time load validation only loads
   the *seed* packages; the `Smoke test` step actually loads the app (entry + ui/server) the way the
   shell does, so it catches code-level startup errors and indirect deps -- and prints the real R
   error. Keep `SMOKE: "on"`.

**The app needs data the repo does not ship.** Some apps read a data file/DB at startup that is
   not committed -- e.g. MutationExplorer opens `data/scanb.sqlite` (`unable to open database file`),
   and shiny-genome-stats reads `data/genome_*.tsv` that are *generated* by `scripts/prefetch_genomes.R`
   (NCBI `datasets` CLI + downloads). The build's app-start smoke test catches this (`... does not exist
   in current working directory`). Either add a build step that fetches/generates the data into `app/`
   before zipping, or treat the app as **not self-contained** and defer it. When the data can be generated with network at build time, use the same prefetch recipe (`references/startup-data.md`); this also removes a first-launch download that would otherwise time out on the user's machine.

**A package-fn demo object may no longer exist.** When the entry builds a demo object (e.g.
   `explor(FactoMineR::PCA(FactoMineR::decathlon[...])))`), a package update can remove it
   (`'decathlon' is not an exported object from 'namespace:FactoMineR'`). Prefer a stable built-in
   dataset (`iris`). The smoke test reports the exact `Caused by error` line.

**The only entry point starts its own Shiny server.** A package that exposes only `launch...()`
(`runApp()`/`startApp()` inside) returns a handle, not a `shinyApp` object, so an `app.R` calling
it either nests a server or leaves the shell with no app object (smoke: "app did not produce a
shiny app object", or the step hangs). Build the app object and return it -- reproduce the
launcher's `shinyApp(ui, server)` from the package internals (`pkg:::`), or ask upstream to
export an app-returning function; bundle demo data if the entry needs one. See
`references/app-shapes.md` (GateLabR).

## Heavy apps and module-level failures

These come from multi-module apps (xOmicsShiny, ScRDAVis). Full playbook:
`references/heavy-apps.md`; macOS dylibs: `references/macos-portability.md`.

- **A dependency is only loaded on click.** `library(PCSF)` inside an `observeEvent()`
  never runs during `shinyAppDir()`, so the smoke test stays green while the module is
  broken. The template now fails the build when any `library()`/`require()`/`pkg::` name
  in the app sources is absent from `rlib/`. Test each module in the real shell anyway.
- **An archived/GitHub-only install failed silently.** A `try()` around
  `install.packages()` shipped a bundle without PCSF. The loop is now fatal on error, and
  `FORCED_PKGS` must all be present in `rlib/` after `ARCHIVE_URLS` installs.
- **Absolute paths from the author's machine.** xOmicsShiny's `config.csv` had
  `server_dir = D:/customProjects_NEW/...`. Patch such files at build time with
  `PATCH_SCRIPT`; never assume relative-path handling.
- **Recommended packages as extras.** Listing `cluster` in `EXTRA_PKGS` forced a source
  build on the runner and failed. Base **and recommended** packages now count as present;
  remove them from the list.
- **Reference genomes blow the size limit.** Two `BSgenome` packages are ~1.4 GB before
  the dependency stack; the full ScRDAVis bundle cannot fit under the 2 GiB release limit.
  Drop or guard the heavy feature, and say which module is disabled in `APP_NOTES`.
- **Version assembled from several refs.** `mainv3.0.1` came from concatenating
  `release.tag_name` + `ref_name` + `inputs.tag`. Use one source (`inputs.tag || github.ref_name`).
- **No upstream license.** A repo with no `LICENSE` needs explicit permission from the
  author before listing, independent of whether the CI now works.

## Ops

15. **Fork names preserve the original case** (e.g. `fentouxungui/PlotsOfData`, not
    `plotsofdata`) and old-name remotes redirect. Use the exact fork name in the catalog `repo`;
    keep the lowercase `<id>` for the asset prefix and catalog id.
16. **The app never appears in the store.** `publish-catalog` discovers assets by the
    **`<id>-<version>-<platform>.zip`** filename from the repo's **latest Release**. A
    wrong `id`, wrong filename, or no published Release = no catalog entry.
17. **Verify, always.** Read back `https://<owner>.github.io/ShinyApps/catalog.json` and
    confirm the app's `version`, both platform artifacts, and their `sha256`.
