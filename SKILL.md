---
name: shinyapps-onboarding
description: Onboard a Shiny-app GitHub repository into the ShinyApps desktop app store (fentouxungui/ShinyApps) end to end - feasibility assessment, fork, a per-repo prebuilt bundle workflow, tag-driven GitHub Actions release, catalog entry and icon, and an upstream pull request. Use when the user wants to publish or "上架" a Shiny app repo to the ShinyApps store, add a desktop bundle for a Shiny app, or reuse the hardened "Route A" prebuilt-bundle onboarding.
---

# ShinyApps onboarding

Publish any Shiny-app repository to the **ShinyApps** desktop app store using the hardened
**"Route A"** route: a per-repo GitHub Actions workflow builds prebuilt desktop bundles
(Windows `win-x64`, macOS `mac-arm64`, R 4.6.1) and attaches them to a GitHub Release; a
catalog entry + icon make the app installable without rebuilding the store shell.

Read `references/failure-modes.md` first, then `references/app-shapes.md`,
`references/store-contract.md` and `references/release-hardening.md` before touching a
workflow.

## When to use

- publish / "上架" a Shiny app GitHub repo to the ShinyApps store;
- add a prebuilt desktop bundle so users need no local R install;
- reproduce the onboarding done for iSEE, UCSCXenaShiny, spatialLIBD, beeRapp,
  CSBB-Shiny, SeuratExplorer, scConvertShiny, shinyCircos-V2.0, UpSetR-shiny, bestDEG,
  GraphBio, splitKbCompare and ShinyStan.

Do **not** use for non-Shiny apps, or apps that need a server-side engine the bundle
cannot ship (give a feasibility caveat).

## App shapes

- **flat** -- `app.R`, or `ui.R`+`server.R` (incl. legacy `shinyUI`/`shinyServer`): copy
  the sources; the runtime runs the directory. Do not synthesize an entry.
- **package-fn** -- an R package whose exported function returns a `shinyApp` object:
  `ENTRY_FN` is that call; install the package.
- **package-deploy** -- an app directory inside an R package that reads package internals:
  copy the app files, prepend `library()` lines, supply data via an RData (mirror the
  package's own `deploy_*()` helper). Do **not** use `library(pkg)` + `pkg:::` + `runApp`.

`assets/build-app-bundle.yml` handles all three (`APP_MODE: auto|flat|package-fn|package-deploy`).

## Procedure

1. **Feasibility (gate).** Confirm the app runs from a directory or matches a package
   recipe; that dependencies resolve on CRAN/Bioconductor (archived via `ARCHIVE_URLS`,
   extra repos via `EXTRA_REPOS`); that no unshippable runtime engine is required (else
   record it in `APP_NOTES`); that no successful start depends on a first-launch
   download (plan a build-time prefetch -- see `references/startup-data.md`); and the
   license. For a heavy app (many modules, a large `data/`/`db/`, GitHub-only packages,
   `BSgenome.*`), also size the bundle and plan build-time patches before the first
   build -- see `references/heavy-apps.md`. Proceed only when high.
2. **Fork** the upstream repo.
3. **Generate + push** `.github/workflows/<id>-build-app-bundle.yml` from
   `assets/build-app-bundle.yml`, filling the `env:` block -- every `__PLACEHOLDER__`,
   including `APP_MODE`, `STRICT_VERSION`, `STRICT_DEPS`, `CRAN_SNAPSHOT`,
   `PANDOC_VERSION`, `MACOS_BREW_DEPS`, `PKG_VERSION_PACKAGES` and
   `PKG_VERSION_SUFFIX`. Unsubstituted `__X__` values fall back to safe defaults.
4. **Tag** `vX.Y.Z` and push -> builds both platform bundles and creates the Release.
5. **Onboard**: append the entry from `assets/catalog-entry.yml` to
   `ShinyApps/catalog/apps.yml`, add `ShinyApps/icons/<id>.png` (from the upstream repo's own logo), push.
6. **Open the upstream PR** (CI-only; see `references/pr-template.md`).
7. **Record it** with `scripts/record-app.ps1 -AppId <id> -Fork <owner>/<repo> -Upstream
   <owner>/<repo> -Tag <tag>`: it snapshots the workflow **at the tag**, the asset sizes and
   the commit SHAs, then scaffolds `meta.yml` + `NOTES.md`. Fill `decisions` and the debug
   log, then run `scripts/validate-apps.ps1` and `scripts/build-app-index.ps1`. Record failed
   and rejected attempts too (`status: abandoned|rejected`); they are the most useful evidence.

Fast path: run `scripts/onboard-shiny-app.ps1` (steps 2-6), then `record-app.ps1` for step 7.

## Hard rules

- Store `id` must be lowercase `^[a-z0-9][a-z0-9-]*$` and equal the release asset prefix
  `<id>-<version>-<platform>.zip`.
- The app must run from a directory; never rely on `pkg:::` + `runApp()` from the bundle.
- Pin to **R 4.6.1**.
- **Bump the version on every change** -- same version = no client `Update`.
- **Tag policy.** With `STRICT_VERSION: "auto"` (default) a package tag must equal
  `DESCRIPTION` `Version`; a repo without a `DESCRIPTION` uses the tag as the store
  version. Use `on` to require a `DESCRIPTION`, and `off` only for a deliberate
  mismatch documented in `APP_NOTES` and the PR. Never ship a silent mismatch.
- **Immutable releases.** One tag trigger; refuse to overwrite a published release
  asset. A second trigger (`release: published`) double-builds the same tag.
- **Fail loud.** Required and transitive dependencies missing from the configured
  repositories fail the build (`STRICT_DEPS: "on"`); list genuinely optional packages
  in `SOFT_PKGS` instead of letting them disappear.
- **Use the app's own icon.** Follow `references/icon-sourcing.md`: repository logo files -> README/HTML -> pkgdown -> the project site linked from the repo About/README -> generate only as a last resort. Reject platform logos, screenshots and badges; never overwrite an already-correct icon.
- **PR quality is part of onboarding.** Every upstream PR must use
  `references/pr-template.md`: explain what ShinyApps is, why the workflow exists, the
  exact diff scope (one YAML file, no app code), the impact (Actions minutes only on tags,
  credit), what the maintainer must do, and an explicit opt-out. One-line "adds a workflow"
  PRs are not acceptable and damage the store's reputation.
- **Verify** `catalog.json` shows the app with the expected artifacts + `sha256`
  (Windows-only apps have no mac asset; document the deviation).
- **Patched packages need unique versions.** If you vendor dylibs into a package (Cairo,
  gdtools, ...) or otherwise modify it per app, set `PKG_VERSION_PACKAGES` +
  `PKG_VERSION_SUFFIX` so each app's copy has a distinct version; allocate it with
  `scripts/next-pkg-version.ps1`. Never reuse a suffix, and never patch only the newest
  app -- every app that ships the package must differ (`references/special-packages.md`).
- **Every attempt gets a record.** `apps/<id>/` holds the exact generated workflow and the
  debug log. `ShinyApps/catalog/apps.yml` remains the only source of truth for what is
  listed; `status` in `meta.yml` only describes build/authorization state. A rejected app
  stays in `apps/` with `status: rejected` and a "do not redistribute" banner.

## Reliability

The workflow ships a **`Smoke test`** step that starts the built bundle with `shiny::runApp()` in a child
process (clean library: `rlib` + base R), waits for the server and requests `/`; it fails unless an HTML
page comes back, and prints the child's output on failure. Constructing the app object (`shinyAppDir()`)
is not enough -- a `ui` function, an `onStart` hook or a resource-loading error can fail only once the
server runs. See `references/failure-modes.md`. Turn it off with `SMOKE: "off"` for apps that need network
at startup.

A **module that the user explicitly opens** may fetch its own large data on first use
(one artifact at a time, into a user-writable library, with progress and a readable
failure) -- this is the only allowed exception to the no-startup-download rule. Conditions
and a reference implementation: `references/runtime-downloads.md`. The shell moves
`app/rlib` into a shared library after install, so a per-user library outside the app
directory survives and vendored dylibs travel with their package -- keep the user library
**appended** to `.libPaths()`.

**Apps that fetch a database at first launch** (a reference DB, taxonomy, annotation bundle)
must not do it from the bundle: the user may be offline and R's default `download.file` timeout
(60 s) aborts a large download mid-stream, so the app errors on start. Generate that data at
build time and ship it inside `app/`, so the app's own "file exists?" guard is satisfied and it
never downloads. Point the workflow's `PREFETCH_SCRIPT` at a repo R script; the template runs it
inside the bundled `app/` with `rlib/` on `.libPaths()` before zipping. For a heavy dump, generate
once in a separate job and pass it as an artifact. Recipe: `references/startup-data.md`.

The template builds the dependency graph from the **source** index, uses `pkgType="both"`
(binary then source), runs a fix-up loop, load-validates seed packages from `rlib/`,
excludes base and recommended packages, and audits macOS binaries for XQuartz/Homebrew
links. It also fails when any `library()`/`require()`/`pkg::` name in the app sources is
missing from `rlib/`, because the smoke test renders the UI once but never clicks a module --
a package loaded inside a click handler otherwise stays invisible until a user presses the
button.

Archived and GitHub-only packages go through `ARCHIVE_URLS` and must be named in
`FORCED_PKGS`; a failed archive install aborts the build. Build-time config patches
(absolute author paths, disabling a module that cannot ship) go in `PATCH_SCRIPT`, which
runs inside `bundle/app/` before zipping. Recipes: `references/heavy-apps.md`. macOS
portability: `references/macos-portability.md`.

## Field lessons (batch CRAN sweep)

- The template uses `__APP_ID__`, `__APP_SUBDIR__`, `__ENTRY_FN__`, ... placeholders. When generating a
  workflow by hand, replace **every** placeholder; an unsubstituted `__ENTRY_FN__` fails only at smoke time.
- `APP_MODE: "auto"` selects `flat` only when the repo has no `DESCRIPTION`. If the app lives in
  `inst/<dir>` (or any subdirectory of a package), set `APP_MODE: "flat"` plus `APP_SUBDIR` explicitly.
- YAML quoting: an `ENTRY_FN` containing double quotes must use single quotes inside the YAML string,
  e.g. `ENTRY_FN: "local({ source('app.R') })"`, or the workflow never triggers.
- `package-fn` works only when the exported function **returns** a `shinyApp` object. A launcher that calls
  `runApp()` blocks and makes smoke time out after the 300 s budget -- use `SMOKE: "off"` only after the log
  shows `Listening on http://127.0.0.1:...` (evidence the app really starts), or build a `shinyapps/app.R`
  adapter that returns the object.
- `flat` bundles only the app directory. Paths in `ENTRY_FN` are relative to that directory, not the repo root.
- macOS: an OpenMP symbol error (`___kmpc_barrier`, `kohonen.so`, ...) is fixed by
  `SOURCE_REBUILD: "<pkg>"`. XQuartz-only links (`Cairo` via `ggrastr`) are **not** a dead
  end: vendor the X11 dylibs into the package's `libs/` with `install_name_tool` + ad-hoc
  `codesign` (ScRDAVis v1.1.2 ships both platforms this way, +15-30 MB). `tcltk`/Tcl-Tk is
  still hard -- guard or drop that module. Source packages needing openssl/hdf5 use
  `MACOS_BREW_DEPS`. Never put `dylibbundler` in a loop -- it hangs; see
  `references/macos-portability.md`.
- Poll CI by workflow name **and** the tag on `head_branch`; otherwise a stale failed run matches first.
- `cran/*` repos are read-only mirrors: onboard the fork but do not open an upstream PR.
- `ARCHIVE_URLS` accepts a monorepo tarball whose package sits in a subdirectory (BPCells in
  `r/`): the template locates the single `DESCRIPTION` and installs that package's Imports
  first. A tarball with several packages fails on purpose -- pass a package tarball.
- Publish **Windows-only** when a macOS dependency cannot be made portable (see
  `references/macos-portability.md`): remove the `macos-14` matrix entry and record it in
  `APP_NOTES`; do not ship a mac zip that cannot start.

## Field lessons (upstream PR review: FielDHub, Familia)

- **Sync the fork before tagging.** Familia's fork was 13 commits behind upstream: its
  `DESCRIPTION` said 2.0.0 while upstream and CRAN were 2.2.0. The PR diff still showed one file
  (GitHub compares the merge base), so the gap was invisible in review. Merge upstream into the
  fork before building, and verify `DESCRIPTION` at the checked-out ref, not in the browser.
- **One version source, and check out the tag.** Concatenating `release.tag_name + ref_name +
  inputs.tag` produced `2.2.0v2.2.0`; a manual run from `main` produced `mainv2.2.0`. Select
  `inputs.tag || github.ref_name`, strip `v`, and set `actions/checkout` `ref: ${{ inputs.tag ||
  github.ref }}`. A manual run with a tag must build that tag; a bad tag should fail at checkout,
  never ship default-branch code.
- **Construction is not startup.** `shinyAppDir()` returns the app object without running the
  server; a `ui` function, `onStart` hook or resource-loading error passes silently. Both a human
  maintainer and Copilot rejected this. The template now runs `shiny::runApp()` and GETs `/`.
- **package-fn: a CRAN copy can mask a failed local install.** When the app is on CRAN, the
  dependency closure installs it; if the checked-out source then fails, `install.packages()` only
  warns and the directory check passes, so the CRAN build ships under the new tag. Exclude the
  package from the closure, `unlink()` any existing copy, install the source, and compare the
  installed `DESCRIPTION` version with the source.
- **Suggests-only packages can hide a user-facing feature.** Familia's SNMF/ancestry tab needs
  LEA, which is only in `Suggests`: the bundle built, but the app told users to install LEA. Check
  `Suggests` during the feature inventory; add such packages to `EXTRA_PKGS` (LEA is
  Bioconductor-only, has no system requirements and compiles on both runners), or document the
  feature as unavailable in `APP_NOTES` and the PR.
- **The icon must be the app's own identity.** Familia's store icon was the Breedverse logo
  (`breedverse_logo.png`) although the repo ships `inst/app/www/familia_logo.png`. Pick the file
  named for the app, then render the 512 px result and look at it; a parent-program or dependency
  logo is a wrong icon, not a style choice.
- **Reply with evidence after review.** State point by point what changed and how it was verified:
  the test tag, both platforms built, the real startup check passed, and the Windows bundle
  installed through the ShinyApps client launches and runs. Then explain releases: pushing a `v*`
  tag builds automatically; a manual run with an existing tag does the same; an empty tag builds
  the branch without a Release where the generated workflow allows it. Keep the PR to one workflow
  file and answer bot reviews in one summary comment (resolve the inline threads).

## Security

`scripts/onboard-shiny-app.ps1` reads the GitHub token via `git credential fill` into the
process environment only and performs fork/push/tag/release/PR on the user's behalf; it
requires a `repo`+`workflow` token. Review before running. The CI build job is
`contents: read`; only the release job may write.

**Release hardening.** Besides the smoke test, the template enforces the tag/version
policy, one immutable release per tag, clean-library smoke (only `rlib` + base R on
`.libPaths()`), fail-fast dependencies, an optional `CRAN_SNAPSHOT` pin and optional
`PANDOC_VERSION`, and publishes `*.sha256`, `meta-*.json` and `deps-*.json`. Checklist:
`references/release-hardening.md`.

## Files

- `assets/build-app-bundle.yml` - hardened multi-mode workflow template.
- `assets/catalog-entry.yml` - catalog entry template.
- `scripts/onboard-shiny-app.ps1` - parameterized driver for steps 2-6.
- `scripts/validate-apps.ps1`, `scripts/build-app-index.ps1`, `scripts/new-app-record.ps1`
  - record checks, index generation and scaffolding (`apps/README.md`).
- `apps/<id>/` - per-app archive: exact workflow, `meta.yml`, `NOTES.md`.
- `references/app-shapes.md`, `references/failure-modes.md`, `references/store-contract.md`,
  `references/startup-data.md`, `references/release-hardening.md`,
  `references/heavy-apps.md`, `references/macos-portability.md`,
  `references/runtime-downloads.md`, `references/special-packages.md`,
  `references/pr-template.md`.
- `examples/` - real workflows for flat, package-fn and package-deploy apps.
