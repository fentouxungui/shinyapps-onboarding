---
name: shinyapps-onboarding
description: Onboard a Shiny-app GitHub repository into the ShinyApps desktop app store (fentouxungui/ShinyApps) end to end - feasibility assessment, fork, a per-repo prebuilt bundle workflow, tag-driven GitHub Actions release, catalog entry and icon, and an upstream pull request. Use when the user wants to publish or "上架" a Shiny app repo to the ShinyApps store, add a desktop bundle for a Shiny app, or reuse the "Route A" prebuilt-bundle onboarding.
---

# ShinyApps onboarding

Publish any Shiny-app repository to the **ShinyApps** desktop app store using the
**"Route A"** route: a per-repo GitHub Actions workflow builds prebuilt desktop bundles
(Windows `win-x64`, macOS `mac-arm64`, R 4.6.1) and attaches them to a GitHub Release; a
catalog entry + icon make the app installable without rebuilding the store shell.

Read `references/store-contract.md` before designing or modifying a workflow.

## When to use

- publish / "上架" a Shiny app GitHub repo to the ShinyApps store;
- add a prebuilt desktop bundle so users need no local R install;
- reproduce the onboarding done for iSEE, UCSCXenaShiny, spatialLIBD, beeRapp,
  CSBB-Shiny, SeuratExplorer, scConvertShiny, shinyCircos-V2.0, UpSetR-shiny, GraphBio,
  splitKbCompare and ShinyStan.

Do **not** use for: non-Shiny apps, or apps whose entry calls `runApp()` itself or that need
a server-side engine the bundle cannot ship (give a feasibility caveat).

## Two app shapes

- **flat** (`app.R`, or `ui.R`+`server.R`): sources copied verbatim, tiny entry generated.
- **package** (app inside an R package, e.g. `inst/<subdir>/`): the package and its closure
  are installed into `rlib/`; entry is `ENTRY_B64` or `shinyAppDir(system.file(...))`.

`assets/build-app-bundle.yml` handles both (`APP_MODE: auto|flat|package`).

## Procedure

1. **Feasibility (gate).** Confirm the contract (entry returns a `shinyApp` object, never
   calls `runApp()`), that dependencies resolve on CRAN/Bioconductor (archived via
   `ARCHIVE_URLS`, extra repos via `EXTRA_REPOS`), that no unshippable runtime engine is
   required (else record it in `APP_NOTES`), and the license. Proceed only when high.
2. **Fork** the upstream repo.
3. **Generate + push** `.github/workflows/<id>-build-app-bundle.yml` from
   `assets/build-app-bundle.yml`, filling the `env:` block.
4. **Tag** `vX.Y.Z` and push -> builds both platform bundles and creates the Release.
5. **Onboard**: append the entry from `assets/catalog-entry.yml` to
   `ShinyApps/catalog/apps.yml`, add `ShinyApps/icons/<id>.png`, push.
6. **Open the upstream PR** (CI-only; see `references/pr-template.md`).

Fast path: run `scripts/onboard-shiny-app.ps1` (steps 2-6).

## Key rules

- Store `id` must be lowercase `^[a-z0-9][a-z0-9-]*$` and equal the release asset prefix
  `<id>-<version>-<platform>.zip`.
- The entry must **return a `shiny.appobj`** and never call `runApp()`; the app dir is the
  working directory, so relative asset paths resolve.
- Pin to **R 4.6.1**; install closure in two passes (binary, then source fallback).
- Verify `catalog.json` contains the app with both artifacts + `sha256`.

## Security

`scripts/onboard-shiny-app.ps1` reads the GitHub token via `git credential fill` into the
process environment only and performs fork/push/tag/release/PR on the user's behalf; it
requires a `repo`+`workflow` token. Review before running.

## Files

- `assets/build-app-bundle.yml` - dual-mode workflow template.
- `assets/catalog-entry.yml` - catalog entry template.
- `scripts/onboard-shiny-app.ps1` - parameterized driver for steps 2-6.
- `references/store-contract.md` - bundle/manifest/catalog contract.
- `references/pr-template.md` - upstream-PR structure.
- `examples/` - real workflows for a flat app and a package app.
