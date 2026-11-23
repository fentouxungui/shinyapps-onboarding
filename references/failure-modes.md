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
   `Imports` to be present. Install the full transitive closure, not just direct deps; a
   local `install.packages(..., repos = NULL, dependencies = FALSE)` does not resolve them.
   See the ARCHIVE_URLS section below.
10. **Huge closure / Release asset > 2 GiB.** Trim optional modules, drop dev-only packages
   (`devtools`, `usethis`, runtime `install_*.R` bootstraps), and `EXCLUDE` large source
   assets (`.ai`/SVG/raw/ screenshots). The workflow size-guards the asset.
11. **Subtracting the whole `installed.packages()` set drops toolchain packages.** A workflow
   that does `setdiff(closure, rownames(installed.packages()))` also removes packages that are
   merely present in the **CI toolchain** (`jsonlite`, `zip`, `digest`, `BiocManager`, `callr`,
   `curl`) even when the app needs them at runtime → `there is no package called 'X'` after install.
   Exclude only **base/recommended** (`installed.packages(priority = c("base", "recommended"))`),
   never all of `installed.packages()`. The current `assets/build-app-bundle.yml` already does
   this; re-onboard any app still built with an older per-app workflow (its bundle is missing
   those packages).
12. **`Rscript: cannot open file '-f'` or a Windows segfault at a script step.** `-f` is an
   R flag, not an `Rscript` flag. Invoke `Rscript script.R` (positional); the template does
   this and runs a setup preflight with the same form.
13. **macOS audit reports many binary packages at once** (`Biobase.so`, `DESeq2.so`,
   `RcppArmadillo.so`, ...). Portable R's `.portable` environment did not run, so CRAN
   binary `.so` files still point at `/Library/Frameworks/R.framework`. An empty
   `R_PROFILE` disables the site profile; set it explicitly to
   `$PORTABLE_R_HOME/etc/Rprofile.site` and use `R_PROFILE_USER` to put the harness
   library back. See `references/macos-portability.md`.
14. **Workflow rejected before any job starts: `Exceeded max expression length 21000`.**
   GitHub evaluates a whole `run:` block as one expression when the block contains
   any `${{ }}`. A long heredoc (the assemble/zip scripts are tens of kilobytes)
   plus even one interpolated value can pass that limit. ScRDAVis failed at
   `Assemble bundle` because `platform <- "${{ matrix.platform }}"` was inside a
   24,641-character `run:` block. The fix is to move every matrix value out of the
   script into `env:` and read it with `Sys.getenv()`:

   ```yaml
   - name: Assemble bundle
     shell: bash
     env:
       BUNDLE_PLATFORM: ${{ matrix.platform }}
     run: |
       ...
       platform <- Sys.getenv("BUNDLE_PLATFORM")
   ```

   The limit is per block, before evaluation, so shortening the value or the
   matrix does not help. Split the step or move the script to a committed file if
   the block itself must stay large. `actionlint` does not detect this.

## Windows source installs from ARCHIVE_URLS: transitive dependencies

**Symptoms.** A pure-R GitHub archive installed with `repos = NULL, type = "source"` fails
with `installation of package ... had non-zero exit status`; the package that imports it then
fails with `ERROR: dependencies 'X' are not available`. The CI log may show only the wrapper
error, not the package-level `00install.out`.

**Root cause.** `install.packages(<local-dir>, repos = NULL, type = "source",
dependencies = FALSE)` installs exactly one package and does **not** resolve dependencies.
Installing only the archive's direct deps with `dependencies = FALSE` also skips their
transitive closure. A package with no `src/` and no `NeedsCompilation` still fails at the
`R CMD INSTALL` dependency check; this is not a compiler, Rtools, Rcpp or system-library
problem.

**Real case (scRNAtoolVis).** Four pure-R archives were pinned in `ARCHIVE_URLS`:
`jjAnno`, `jjPlot`, `ggunchull`, `scRNAtoolVis`. Their declared deps have large closures:

| archive | direct CRAN/Bioc deps | transitive closure |
|---|---|---|
| `jjPlot` | `tidyverse`, dplyr, ggplot2, magrittr, scales | ~107 packages |
| `ggunchull` | `alphahull`, `dbscan`, `polyclip`, ggplot2, magrittr | ~52 packages |
| `jjAnno` | `ggiraphExtra`, `magick`, dplyr, ggplot2, magrittr | ~82 packages |

The workflow installed only the direct deps, so `jjPlot` and `ggunchull` failed; then
`scRNAtoolVis`, which imports both, failed with `dependencies 'jjPlot', 'ggunchull' are not
available`. None of the four packages has `src/`, `NeedsCompilation`, `LinkingTo` or
`SystemRequirements`.

**Diagnosis.**

1. Read each archive's `DESCRIPTION`: `Package`, `Version`, `NeedsCompilation`,
   `SystemRequirements`, `Depends`, `Imports`, `LinkingTo`, `Remotes`.
2. If there is no `src/` and no `NeedsCompilation: yes`, stop looking for Rtools/system
   library fixes and resolve the R dependency graph.
3. Expand the declared deps with
   `tools::package_dependencies(deps, db = available.packages(type = "source"), recursive = TRUE)`.
4. Verify the GitHub URL, package name and case. Keep dependencies before their dependents;
   scRNAtoolVis must be last. Reordering alone does not fix missing transitive deps.
5. Reproduce and read the real error; see the Windows commands below.

**Reproduce on Windows.**

```powershell
$lib = "C:\temp\rlib"
New-Item -ItemType Directory -Force $lib | Out-Null
# Same local-source path as CI, with output preserved:
Rscript -e 'install.packages("C:/temp/jjPlot-4a27a4ca...", lib="C:/temp/rlib",
  repos=NULL, type="source", dependencies=FALSE, Ncpus=1,
  INSTALL_opts=c("--no-multiarch","--preclean","--no-clean-on-error"))'
type C:\temp\rlib\jjPlot\00install.out

# Or call R CMD INSTALL directly:
& "C:\Program Files\R\R-4.6.1\bin\x64\R.exe" CMD INSTALL `
  --no-multiarch --preclean --no-clean-on-error --library=C:\temp\rlib `
  C:\temp\jjPlot-4a27a4ca...
```

The real error is in `00install.out` (usually `dependencies 'tidyverse', ... are not
available` or `there is no package called 'Rcpp'`). `--no-multiarch` / `--preclean` do not fix
the dependency problem for pure-R packages; they expose the real error.

**Fix.**

The template's `install_archive()` now installs the full closure of the archive's declared
deps before the archive:

```r
need <- setdiff(dcf_deps(dcf), c(have(), base_pkgs))
need <- intersect(need, rownames(db))
need_all <- unique(c(need, unlist(tools::package_dependencies(need, db = db, recursive = TRUE))))
need_all <- setdiff(intersect(need_all, rownames(db)), c(have(), base_pkgs))
if (length(need_all)) ins(need_all, deps = FALSE)
install.packages(pkgdir, lib = lib, repos = NULL, type = "source", dependencies = FALSE)
```

For an app-level belt-and-suspenders fix, add the archives' direct CRAN deps to `EXTRA_PKGS`
so the main closure resolves them before `ARCHIVE_URLS` runs. For the scRNAtoolVis case:

```yaml
EXTRA_PKGS: "scRNAtoolVis qs2 tidyverse alphahull dbscan polyclip ggiraphExtra magick"
```

Keep every archive package in `FORCED_PKGS`; the template aborts if one is missing.

The template also adds a `Verify Windows R toolchain` step that fails when `Sys.which("make")`
or `Sys.which("gcc")` is empty. The four archives above are pure R and do not need a compiler,
but some of their CRAN dependencies do; this check catches a missing Rtools before the
package-level errors. If that step exits 255 with no R output, see the portable-R section
below; it is a launcher problem, not a missing `make`/`gcc`.

**Verify in CI.**

`FORCED_PKGS` must print:

```text
forced packages ok: jjAnno jjPlot ggunchull scRNAtoolVis
```

Then check `bundle/rlib/<pkg>/` for all four, inspect `manifest.json` `packages[]`, and require
the smoke test to print `SMOKE OK: ... served an HTML page`. A successful artifact upload is
not enough if the smoke test was skipped.

## Portable R invocation (Windows): `R_HOME`/launcher can exit 255

**Symptoms.** After `Set up portable R`, a bare `Rscript` or an absolute
`"$PORTABLE_RSCRIPT"` can fail with `The system cannot find the path specified.`
(process exit 255). The R code never runs (no `R:` output), so this is **not** a
`make`/`gcc` failure. In a real case, `R_HOME` was correct and the file existed;
the first call with `R_HOME=` empty succeeded, while the next call with the same
`R_HOME` exported failed.

**Cause.** There are two related Windows launcher/PATH failures:

1. Setting `R_HOME` to the portable root (even a correct path) after the setup
   can make `Rscript.exe` fail before R starts. On Windows keep `R_HOME` empty
   and let Rscript self-locate; macOS keeps the explicit portable `R_HOME`.
2. Adding the portable `bin` to `GITHUB_PATH` as a forward-slash drive path
   (`D:/.../bin`) can make Windows `where`/R `Sys.which` fail with
   `The system cannot find the path specified.` A call that only runs
   `R.home()` can succeed, while the next call using
   `Sys.which("make")`/`Sys.which("gcc")` exits 255 without visible R output.
   A bare `Rscript` can also resolve to the runner's framework R or a shim.

macOS does not use this launcher/PATH combination and is unaffected.

**Fix.** On Windows, do not export `R_HOME`; let the portable Rscript self-locate.
The setup writes `R_HOME=` empty to `GITHUB_ENV` on Windows (keep the portable
`R_HOME` only on macOS), and it does **not** add the portable bin to
`GITHUB_PATH`. Every later step invokes the absolute `"$PORTABLE_RSCRIPT"`.
Check `make`/`gcc` with the shell's `command -v`, not with R `Sys.which`.

```yaml
# setup step:
if [ "$(uname -s)" = "Darwin" ]; then
  export R_HOME="$PORTABLE_R_HOME"
  echo "R_HOME=$PORTABLE_R_HOME" >> "$GITHUB_ENV"
else
  export R_HOME=
  echo "R_HOME=" >> "$GITHUB_ENV"
fi
# Do NOT echo dirname(rscript) into GITHUB_PATH; later steps use:
# "$PORTABLE_RSCRIPT"

# first post-setup step:
: "${PORTABLE_RSCRIPT:?PORTABLE_RSCRIPT is not set by the portable-R setup}"
PORTABLE_RSCRIPT="$(printf '%s' "$PORTABLE_RSCRIPT" | tr -d '\r')"
test -f "$PORTABLE_RSCRIPT"
R_HOME= "$PORTABLE_RSCRIPT" -e 'cat(R.home())'   # diagnostics only
R_HOME= "$PORTABLE_RSCRIPT" -e 'cat("R:", R.version.string, "\n")'
for tool in make gcc; do
  command -v "$tool" >/dev/null || { echo "::error::$tool not found"; exit 1; }
done
echo "toolchain OK: $(command -v make) | $(command -v gcc)"
```

Do not use bare `Rscript` after the portable-R setup. Keep the script path
positional (`"$PORTABLE_RSCRIPT" script.R`); `-f` is an R flag, not an Rscript flag.

**Follow-up checks.** Print `PORTABLE_RSCRIPT` and both inherited/self-located
`R_HOME`. Validate the file with `test -f` and the self-located directory with
`[ -d ]`. If 255 persists with `R_HOME` empty:
* grep the setup log for `GITHUB_PATH` and remove the portable bin entry;
* replace R `Sys.which("make"/"gcc")` with shell `command -v`;
* inspect `command -v Rscript`, the portable-R extraction/symlinks, and the
  launcher/R_HOME combination.

Do not "fix" Windows by exporting the portable `R_HOME` or by adding its bin to
PATH; those are the failure modes. Only after the R code actually runs should a
`make`/`gcc` message be treated as a Rtools problem. Record the empty-`R_HOME`/
absolute-Rscript fix in the workflow header/app notes.

## Smoke test: harness/site library leaks into the child

**Symptoms.** On macOS the smoke child exits before serving:

```text
smoke: unexpected library paths: /Users/runner/work/_temp/shinyapps-portable-r/harness-root/harness
Error: Error: smoke test FAILED: the app exited before serving a page
```

**Cause.** The portable-R setup puts the build harness in
`R_LIBS_SITE`/`R_LIBS_USER`. The `callr` child inherits those; additionally,
`.libPaths(c(lib, .Library))` includes `.Library.site` by default, so the harness
appears as an extra library path and the clean-library assertion stops the child
before `shiny::runApp()`.

**Fix.** In the smoke child use:

```r
.libPaths(c(lib, .Library), include.site = FALSE)
```

and launch it with a clean library environment:

```r
callr::r_bg(serve, args = list(appdir = appdir, lib = lib, port = port),
            supervise = TRUE,
            env = c(R_LIBS_SITE = "", R_LIBS_USER = "", R_LIBS = ""))
```

Keep the `allowed` check: it must now see exactly `rlib` and base R. The harness is
build-only and must never be visible to the app smoke test.

**Follow-up.** If any platform reports extra library paths, print `.libPaths()` and
the `R_LIBS_*` variables inside the child. The app's real dependencies must still be
in `rlib`; fixing the harness leak must not remove the clean-library assertion.

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

**macOS: R crashes with `SIGKILL (Code Signature Invalid)` / `Namespace CODESIGNING, Code 2 Invalid Page` while loading a package.**
Portable R's `.portable` wrapper rewrites CRAN binary `.so` load commands after
`install.packages()` without re-signing them. macOS kills R when it loads the modified
binary. `codesign --verify` on the `.app` can still pass because the failing file often
lives in the shell's shared library (`~/Library/Application Support/<slug>/lib`), outside
the app bundle; a real case was `data.table/libs/data_table.so`. The template's macOS
re-signing step fixes this at build time. For an installed app, re-sign the `.so`/`.dylib`
files in that library with `codesign --force --sign -` and verify them. See
`references/macos-portability.md`.

**macOS: `Library not loaded: /Library/Frameworks/R.framework/.../libRblas.dylib` from `lib/KernSmooth`.**
A base/recommended package was shipped in `rlib` and copied to the shared library. It links to
the builder's R.framework, which the shell's portable R does not provide. Never ship
base/recommended packages; rebuild the bundle with the current template, and update the shell
so its startup cleanup removes legacy `lib/KernSmooth` copies. See
`references/macos-portability.md`.

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
   (`ARCHIVE_URLS`). Its install-time dependencies must already be present: add the
   archive's direct deps to `EXTRA_PKGS` (e.g. `rgl`, `ellipse` for `pca3d`) and ensure
   their transitive closure is installed. The template's `install_archive()` expands the
   closure; see the section below.

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
- **A tag push built nothing.** The workflow listened only for `release: published`.
  A git tag push is a `push` event, not a release event, so no run appeared. The
  template now triggers on `push: tags`; `release: published` is not a trigger (the
  workflow creates the Release itself, and listening to that event would double-build).
  A tag created through the Release UI may not emit a `push` event either: run the
  workflow manually against it.
- **Version assembled from several refs.** `mainv3.0.1` came from concatenating
  `release.tag_name` + `ref_name` + `inputs.tag`. Use one source (`inputs.tag || github.ref_name`),
  strip `refs/tags/` and `v`, require the tag to exist, and check out
  `ref: ${{ needs.resolve.outputs.tag }}`.
- **No upstream license.** A repo with no `LICENSE` needs explicit permission from the
  author before listing, independent of whether the CI now works.
- **A monorepo has more than one `DESCRIPTION`.** BPCells is `r/` inside
  `bnprks/BPCells`, and upstream later added a root `DESCRIPTION` for a sentinel
  package named `BPCells.installation.moved`, so the old "exactly one DESCRIPTION"
  check aborted with `found 2` and blocked `monocle3`. The template now reads each
  candidate's `Package` field and selects the one named in `FORCED_PKGS`
  (`BPCells` -> `r/DESCRIPTION`); if no candidate or more than one candidate
  matches, it fails with the candidate paths instead of guessing. Keep every
  archive package in `FORCED_PKGS` so this selection and the final check work.
- **1.4 GB of reference data on startup.** ScRDAVis cannot ship two `BSgenome` packages
  inside a 2 GiB release next to a 484-package closure. Startup downloads are still
  banned; a user-triggered module download into a user library is the documented
  exception (`references/runtime-downloads.md`).
- **macOS may be impossible, not just hard.** `monocle3` -> `ggrastr` -> `Cairo`/XQuartz
  cannot be made portable. Publish Windows-only, remove the `macos-14` matrix entry, and
  record the limitation instead of shipping a mac asset you cannot start.
- **A package manager ships a nested private library.** `devtools` imports `pak`;
  `pak` places `cli`, `curl`, `pkgcache`, `pkgdepends`, `processx`, `zip`, ... under
  `rlib/pak/library/`. Portable R's `.portable` patcher only rewrites the main
  library, so the macOS audit reports those nested `.so` files as linked to
  `/Library/Frameworks/R.framework`. If the app does not call `devtools::*`, remove
  `devtools` from `EXTRA_PKGS` and delete its startup `require`; otherwise patch and
  re-sign the nested library or drop the feature. See `references/macos-portability.md`.

## Review findings (upstream PR: FielDHub, Familia)

- **The fork is behind upstream.** Familia's fork `main` was 13 commits behind:
  `DESCRIPTION` 2.0.0 vs upstream/CRAN 2.2.0. The PR diff still showed one file because
  GitHub compares the merge base. Merge upstream into the fork, then verify `DESCRIPTION`
  at the tag being built; building the stale default branch ships old source under a new tag.
- **A manual run builds the default branch, not the tag.** `inputs.tag` decides the Release
  that receives the assets, but `actions/checkout` follows the event ref. Run from `main`
  with `v2.2.0` and the bundle contains `main`. The `resolve` job now canonicalizes the
  tag and the build checks out `ref: ${{ needs.resolve.outputs.tag }}`.
- **A manual run created a new Release instead of attaching.** The input `0.1.10` did not
  match the existing `v0.1.10` tag, and `softprops/action-gh-release` treats an unknown
  `tag_name` as "create a Release". The template now resolves the canonical `v<version>`
  once, requires it to exist, uses `gh release upload` (which never creates a Release), and
  fails a manual run whose tag has no Release. Do not add `release: published` to "fix"
  the trigger: the workflow's own Release would start a second build; a tag push is the
  trigger, and a manual run is attach-only.
- **The smoke test constructs the app but never starts it.** `shiny::shinyAppDir(".")`
  returns a `shiny.appobj` without running the server, so a `ui` function, an `onStart`
  hook or a missing resource passes while the real app would fail. Start the bundle with
  `shiny::runApp()` in a child process, GET `/`, and require HTTP 200 + HTML. The template
  now does this; re-onboard any app still built with an older per-app workflow.
- **A CRAN copy masks a failed `package-fn` install.** `seed` contains the app package, so
  `install.packages(closure)` installs its CRAN version first. If installing the checked-out
  source fails, `install.packages()` warns and the existing CRAN directory satisfies
  `pkg %in% have()`, publishing CRAN code under the tag. Exclude the package from the
  closure, `unlink()` the old copy, and verify the installed `DESCRIPTION` version equals
  the source version.
- **A Suggests-only package backs a feature.** Familia's SNMF/ancestry modules need LEA,
  listed only in `Suggests`; the build passed and the app displayed "Install the LEA package
  to use SNMF". Scan `Suggests` during the feature inventory, add such packages to
  `EXTRA_PKGS` and let the load validation cover them, or record the disabled feature.
- **The store icon is another product's logo.** Familia's icon was `breedverse_logo.png`
  (the parent program), not `familia_logo.png`. See `references/icon-sourcing.md`: verify
  the app identity in the rendered 512 px icon.

## GitHub-hosted runner acquisition failure (the job never starts)

**Symptoms.** A matrix leg is `cancelled` with no steps, an empty `runner_name`,
and an annotation such as:

```text
The job was not acquired by Runner of type hosted even after multiple attempts
Internal server error. Correlation ID: ...
Due to capacity constraints, jobs targeting macos arm64 runners may experience
longer queue times.
```

Other platforms finish and the release job publishes only their assets. Because
no runner was assigned, there is no checkout, R log or package error to debug.

**Cause.** GitHub-hosted capacity or a transient runner-service failure, not the
workflow and not the app's dependencies. `macos-15` is the correct arm64 label;
the job never reached `actions/checkout`.

**Recovery.** Retry later (check GitHub status first). Do **not** use
"Re-run all jobs" when a Release already contains one platform's zip: the
release job correctly refuses to overwrite an existing asset. Build only the
missing platform through `workflow_dispatch` with the tag and
`platforms=<missing>`, or through Run Bundle; the release job downloads only the
new artifact and attaches it to the existing Release. Verify the Release asset
list afterwards. If the same runner acquisition failure repeats, wait and retry;
there is no code fix.

## Ops

15. **Fork names preserve the original case** (e.g. `fentouxungui/PlotsOfData`, not
    `plotsofdata`) and old-name remotes redirect. Use the exact fork name in the catalog `repo`;
    keep the lowercase `<id>` for the asset prefix and catalog id.
16. **The app never appears in the store.** `publish-catalog` discovers assets by the
    **`<id>-<version>-<platform>.zip`** filename from the repo's **latest Release**. A
    wrong `id`, wrong filename, or no published Release = no catalog entry.
17. **Verify, always.** Read back `https://<owner>.github.io/ShinyApps/catalog.json` and
    confirm the app's `version`, both platform artifacts, and their `sha256`.
