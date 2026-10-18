# Batch onboarding from a CSV shortlist

Pipeline used for the CRAN Shiny sweep (244-row shortlist).

1. **Filter** the CSV: keep rows with `InStore=False`, empty `RedFlags`, `Componentish=False`, and a
   non-empty `github` URL. Drop packages whose Title is clearly a helper/module (no app).
2. **Classify** each repo with a shallow clone:
   - `git grep -nE "shinyApp|runApp|shinyAppDir" -- R`
   - flat candidate: any directory (repo root or `inst/**`) containing `app.R`, or `ui.R` + `server.R`.
   - `runApp(system.file("...", package="pkg"))` -> flat with `APP_SUBDIR=inst/<that path>`.
   - a function whose body ends in `shinyApp(...)` and is exported -> `package-fn` with
     `ENTRY_FN="library(pkg); fn()"`.
   - a function that calls `runApp()` -> launcher: build `shinyapps/app.R`, or `SMOKE:"off"` only when the
     log proves `Listening`.
   - no `shiny`/`shinyApp` at all -> not a Shiny app; skip and record.
3. **Generate** the workflow from `assets/build-app-bundle.yml`, replacing every `__PLACEHOLDER__`; set
   `APP_MODE` explicitly. One app per fork, one tag per attempt (`v0.1.0`, `v0.2.0`, ...).
4. **Poll** with `workflow_runs` filtered by `name == "Build app bundle"` and the exact tag on
   `head_branch`; wait for `status == completed` before reading `conclusion`.
5. **Finalize**: on success append the catalog entry + icon to `ShinyApps` in one commit; open an upstream
   PR only for real upstreams (never `cran/*`).
6. **Record** failures with the concrete error class (X11, OpenMP, blocking launcher, non-standard entry)
   instead of retrying blindly.

## Detection pitfalls

- A file named `R/app.R`, `R/app_ui.R`, `R/ui.R` is **not** a flat app root. Only a literal
  `app.R` / `ui.R`+`server.R` at the directory that will be copied counts.
- If `git grep` finds `shinyApp(...)` in `R/*.R` and `NAMESPACE` exports a zero-argument function,
  prefer `package-fn` with `ENTRY_FN="library(pkg); fn()"`. Rebuilding after a wrong `flat` guess is one tag bump.
- Functions that take required data arguments (`handcode(data)`, `IMP::staticPerfMeasures(list_models, g)`)
  have no zero-argument entry; skip rather than fabricate demo data.