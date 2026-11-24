# Radiant (`radiant`)

- **Status:** `active` -- bundle built and published (`v1.6.7`), listed in the ShinyApps catalog.
- **Upstream:** https://github.com/radiant-rstats/radiant
- **Fork:** https://github.com/fentouxungui/radiant
- **Release:** https://github.com/fentouxungui/radiant/releases/tag/v1.6.7 (`v1.6.7`)
- **Artifacts:**
  - `radiant-1.6.7-win-x64-r4.6.zip` (193 MB)
  - `radiant-1.6.7-mac-arm64-r4.6.zip` (233 MB)
- **Template:** `2026.11.18.4` (local working tree, ahead of canonical `main` `2026.11.17.7`);
  the only template-behaviour change relevant here is the `${{ }}` max-expression-length fix.

## Why it is packaged this way

| Setting | Value | Reason |
|---|---|---|
| `APP_MODE` | `flat`, `APP_SUBDIR=inst/app` | `inst/app/{ui,server,global}.R` is a directory app *inside* the R package. `global.R` resolves every `radiant.*` module through `system.file()` and `server.R` calls `library(radiant)`, so this is the documented "package whose app directory does `library()`" case -- `flat` + `EXTRA_PKGS`, **not** `package-deploy`. |
| `EXTRA_PKGS` | `radiant radiant.data radiant.design radiant.basics radiant.model radiant.multivariate` | All six are on CRAN: `radiant 1.6.7`, `radiant.data 1.6.9`, `radiant.design 1.6.6`, `radiant.basics 1.6.6`, `radiant.model 1.6.13`, `radiant.multivariate 1.6.9`. The closure is CRAN-only -- no Bioconductor, no GitHub-only, no archived packages. |
| `FORCED_PKGS` | same six | A silent CRAN miss must fail the build instead of shipping a navbar with a dead module. |
| `EXCLUDE` | `rsconnect,tests,for.shinyapps.io.R` | `rsconnect/` is shinyapps.io deployment metadata; `tests/` is a `ShinyDriver` script; `for.shinyapps.io.R` is a dev helper whose commented `library()` lines would otherwise seed the dependency scanner. |
| `SOFT_PKGS` / `ARCHIVE_URLS` | empty | Not needed -- the closure resolves entirely from CRAN. |
| `SOURCE_REBUILD` / `PKG_VERSION_*` | empty | Nothing recompiled for portability and no vendored dylibs, so no per-app version suffix is allocated (see `apps/pkg-versions.tsv`). |
| `STRICT_DEPS` / `SMOKE` | `on` | Unresolved dependencies fail the build, and the bundle must serve an HTML page before the Release is created. |
| `MAX_REQUEST_MB` | `1024` | Radiant imports user data files; the upload cap needs headroom for typical datasets. |
| `PANDOC_VERSION` | empty | Report > Rmd/R needs pandoc on the *user's* machine. The template only verifies pandoc on the build runner and does not ship it, so pinning a version would add provenance without fixing the runtime. |

## Known limitations

- `arrow` (parquet import) is not bundled -- guarded by `requireNamespace()`, and the UI hides the parquet option when it is absent.
- `webshot` (report screenshots) is not bundled -- it needs phantomjs.
- `DBI`/`RSQLite` are only used by the pkgdown-style DB sync helper in `R/radiant.R`, not by the app, so they are not bundled.
- Pandoc is not shipped (see the table above): Report > Rmd/R needs a local pandoc.
- No startup download: example data ships inside `radiant.data`.

## Debug log

One row per failed run: symptom in the log -> root cause -> fix -> how it was verified.

| # | Symptom (log line) | Root cause | Fix | Verified by |
|---|---|---|---|---|
| 1 | `validate-apps: 1 error(s), 18 warning(s)` / `ERROR apps/radiant: meta.yml missing` (validate-apps + weekly upstream check) | `apps/radiant/` was committed with only `NOTES.md`. `validate-apps.ps1` needs `meta.yml` plus the workflow snapshot, and the 20 provenance fields can only be read from GitHub *after* a Release exists. The missing `build-app-bundle.yml` was masked: the script `continue`s right after a missing `meta.yml`. | Built the record from the published release (release by tag, commit by tag, workflow at tag, upstream head -- the same endpoints `record-app.ps1` uses) and copied the workflow at the tag into this folder. | `scripts/validate-apps.ps1` -> `OK (130 record(s), 18 warning(s))`, exit 0; snapshot sha256 matches the file at the tag. |

No other failed build run is recorded for `v1.6.7`. `xgboost` (imported by `radiant.model`) was the expected macOS risk (libomp), but no `MACOS_BREW_DEPS` / `SOURCE_REBUILD` entry was needed -- both platform assets and the `Smoke test` step completed.

## Reuse notes

- The pattern to copy: a CRAN package whose `inst/app` is a directory app that `library()`s the package itself. `APP_MODE=flat` + `APP_SUBDIR=inst/app` + `EXTRA_PKGS`/`FORCED_PKGS` = the package's own module set.
- Excluding a dev helper whose commented `library()` lines seed the scanner (`for.shinyapps.io.R`) is worth checking for in any package-fork app.
- Icon: `radiant.data/inst/app/www/imgs/icon.png` is the app's own favicon (referenced by `tags$link(rel="shortcut icon")`); upscaled 200 -> 512 with Lanczos to `ShinyApps/icons/radiant.png`.
- Catalog entry points at the fork; no upstream PR was opened for this attempt.

## Provenance note

`meta.yml` was assembled from the same GitHub API endpoints `record-app.ps1` calls (release by tag, commit by tag, workflow path at tag, upstream head), because that session had no `GITHUB_TOKEN` and the script refuses to run without one. Cross-check: the recorded `workflow_sha256` equals the LF-normalised sha256 of the workflow file at `v1.6.7` (`4db2c1eb...fed3`), and `source_commit` equals the commit the tag points at.