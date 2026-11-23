# radiant — onboarding notes

**Status:** prepared locally, awaiting push/build (2026-11-23).

| field | value |
|---|---|
| app id | `radiant` |
| upstream | `radiant-rstats/radiant` |
| fork | `fentouxungui/radiant` (in sync with upstream `master`, DESCRIPTION 1.6.7) |
| tag | `v1.6.7` (annotated, local; points at workflow commit) |
| source commit | `74301f6f094c0b0df77331c342a529c372f8d0ea` |
| workflow | `.github/workflows/build-app-bundle.yml` |
| workflow sha256 | `4db2c1eb1d117bac27f42182cd95045350cf34d88dca5cfb4311deacdf63fed3` |
| app mode | `flat`, `APP_SUBDIR=inst/app` |
| license | AGPL-3 (upstream `AGPL-3 | file LICENSE`) |

## Skill version used

Local working tree `2026.11.18.4` at commit `58c4bab0309b493ad7e8219366cda9a1c2ab73b8` with 7
uncommitted files (`SKILL.md`, `VERSION`, `assets/build-app-bundle.yml`,
`references/{failure-modes,independent-platform-releases,macos-portability}.md`,
`apps/scrdavis/NOTES.md`). Canonical `main` at the time of this attempt was
`58c4bab` / `2026.11.17.7`. **This record therefore uses an uncommitted,
locally-ahead template; it is not a canonical release and must be reconciled
before reuse.** The `${{ }}` max-expression-length fix in SKILL.md is the only
template-behaviour change relevant to this app.

## Feasibility

- Shape: `inst/app/{ui,server,global}.R` — a directory app inside the R package
  that delegates to the installed `radiant.*` packages via `system.file()`
  options. This is the documented "package whose app directory does library()"
  case, so `flat` + `EXTRA_PKGS`, **not** `package-deploy`.
- Run check: `global.R` sets `radiant.path.*` options from
  `system.file(package=...)`, sources `radiant.data/app/global.R`, and builds the
  navbar from the five module packages; `server.R` calls `library(radiant)`.
  Everything resolves from installed packages — no repo-relative paths.
- Dependencies: `radiant 1.6.7`, `radiant.data 1.6.9`, `radiant.design 1.6.6`,
  `radiant.basics 1.6.6`, `radiant.model 1.6.13`, `radiant.multivariate 1.6.9`
  are all on CRAN; their closure is CRAN-only (no Bioconductor, no GitHub-only,
  no archived packages). `STRICT_DEPS=on`.
- Unshippable/optional features (documented, not fatal):
  - `arrow` (parquet import) — guarded by `requireNamespace()`; the UI hides the
    parquet option when absent. Not bundled (large binary).
  - `webshot` (report screenshots) — needs phantomjs; not bundled.
  - `DBI`/`RSQLite` — only used by the pkgdown-style DB sync helper in
    `R/radiant.R`, not by the app; not bundled.
  - Pandoc for Report > Rmd/R — `PANDOC_VERSION` left empty: the template only
    verifies pandoc on the build runner and does not ship it to users, so
    setting it would add provenance without fixing the runtime.
- No startup download: example data ships inside `radiant.data`.

## Decisions

- `APP_MODE=flat`, `APP_SUBDIR=inst/app` per `references/app-shapes.md`
  ("A package whose app directory does `library(<pkg>)`").
- `EXCLUDE=rsconnect,tests,for.shinyapps.io.R` — `rsconnect/` is shinyapps.io
  deployment metadata, `tests/` is a `ShinyDriver` script, `for.shinyapps.io.R`
  is a commented dev helper whose commented `library()` lines would otherwise
  seed the dependency scanner.
- `FORCED_PKGS` = the six radiant packages, so a silent CRAN miss fails the
  build instead of shipping a broken menu.
- Icon: `radiant.data/inst/app/www/imgs/icon.png` (the app's own favicon,
  referenced by `tags$link(rel="shortcut icon")`), upscaled 200→512 with
  Lanczos to `ShinyApps/icons/radiant.png`.
- Catalog `repo` points at the fork; no upstream PR requested for this attempt.

## Pending / verification checklist

1. `git push origin master` + `git push origin v1.6.7` in `D:\GitHub_Res\radiant`.
2. Workflow `build-app-bundle` builds `win-x64` and `mac-arm64` from portable R
   4.6.1, runs the smoke test, creates the `v1.6.7` Release and attaches
   `radiant-1.6.7-win-x64-r4.6.zip` / `radiant-1.6.7-mac-arm64-r4.6.zip`.
3. Known likely failure points to watch in CI: `xgboost` (radiant.model import)
   on macOS needs libomp — if the audit reports a Homebrew link, retry with
   `MACOS_BREW_DEPS: "libomp"` and `SOURCE_REBUILD: "xgboost"`; `DiagrammeR`
   and `NeuralNetTools` are pure-R.
4. After the Release exists, `git push origin main` in `D:\GitHub_Res\ShinyApps`
   and confirm `catalog.json` has `radiant` with both artifacts + sha256.
5. Then run `scripts/record-app.ps1 -AppId radiant -Fork fentouxungui/radiant
   -Upstream radiant-rstats/radiant -Tag v1.6.7` to finalise `meta.yml`.
