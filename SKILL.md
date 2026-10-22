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
   license. Proceed only when high.
2. **Fork** the upstream repo.
3. **Generate + push** `.github/workflows/<id>-build-app-bundle.yml` from
   `assets/build-app-bundle.yml`, filling the `env:` block -- every `__PLACEHOLDER__`,
   including `APP_MODE`, `STRICT_VERSION`, `STRICT_DEPS`, `CRAN_SNAPSHOT` and
   `PANDOC_VERSION`. Unsubstituted `__X__` values fall back to safe defaults.
4. **Tag** `vX.Y.Z` and push -> builds both platform bundles and creates the Release.
5. **Onboard**: append the entry from `assets/catalog-entry.yml` to
   `ShinyApps/catalog/apps.yml`, add `ShinyApps/icons/<id>.png` (from the upstream repo's own logo), push.
6. **Open the upstream PR** (CI-only; see `references/pr-template.md`).

Fast path: run `scripts/onboard-shiny-app.ps1` (steps 2-6).

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
- **Verify** `catalog.json` shows the app with both artifacts + `sha256`.

## Reliability

The workflow ships a **`Smoke test`** step that loads the built bundle the way the shell does (bounded,
prints the real error, blocks the release on failure). See `references/failure-modes.md`. Turn it off
with `SMOKE: "off"` for apps that need network at startup.

**Apps that fetch a database at first launch** (a reference DB, taxonomy, annotation bundle)
must not do it from the bundle: the user may be offline and R's default `download.file` timeout
(60 s) aborts a large download mid-stream, so the app errors on start. Generate that data at
build time and ship it inside `app/`, so the app's own "file exists?" guard is satisfied and it
never downloads. Point the workflow's `PREFETCH_SCRIPT` at a repo R script; the template runs it
inside the bundled `app/` with `rlib/` on `.libPaths()` before zipping. For a heavy dump, generate
once in a separate job and pass it as an artifact. Recipe: `references/startup-data.md`.

The template builds the dependency graph from the **source** index, uses `pkgType="both"`
(binary then source), runs a fix-up loop, load-validates seed packages from `rlib/`,
excludes base packages, and audits macOS binaries for XQuartz/Homebrew links. Details and
the full failure catalog: `references/failure-modes.md`.

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
  `SOURCE_REBUILD: "<pkg>"`. A package whose load needs XQuartz (`tcltk`, `summarytools`) is **not**
  shippable on the mac runner; record Windows-only or skip.
- Poll CI by workflow name **and** the tag on `head_branch`; otherwise a stale failed run matches first.
- `cran/*` repos are read-only mirrors: onboard the fork but do not open an upstream PR.

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
- `references/app-shapes.md`, `references/failure-modes.md`, `references/store-contract.md`,
  `references/startup-data.md`, `references/release-hardening.md`, `references/pr-template.md`.
- `examples/` - real workflows for flat, package-fn and package-deploy apps.
