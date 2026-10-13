# App shapes and how to onboard each

Detect the shape from the repo layout, then set `APP_MODE` (the workflow auto-detects
most cases). The shell launches with `shiny::runApp(<app dir>)`, so a directory that
contains either `app.R` **or** `ui.R`+`server.R` is already a valid app -- you usually do
**not** need to synthesize an `app.R`.

| Shape | Signals | How it is handled |
|---|---|---|
| **flat / single-file** | `app.R` ending in `shinyApp(ui, server)`, no `DESCRIPTION` | copied verbatim; the runtime sources it. If it calls `runApp()`, the workflow renames it and generates a wrapper that returns the app object. |
| **flat / multi-file** | `ui.R` + `server.R` (optional `global.R`), not a package | copied verbatim; the runtime builds the app from the directory. No entry synthesized. |
| **flat / legacy** | `ui.R` uses `shinyUI(...)`, `server.R` uses `shinyServer(...)` | same as multi-file -- modern shiny still runs legacy `shinyUI`/`shinyServer` dir apps. |
| **package-fn** | has `DESCRIPTION`; an exported function returns a `shinyApp` object and does **not** call `runApp()` | `APP_MODE=package-fn`, `ENTRY_FN='library(pkg); pkg::fn(...)'`. The package is installed into `rlib/`. |
| **package-deploy** | has `DESCRIPTION`; the app is a directory inside the package (`inst/<subdir>/`) that reads package internals (e.g. `.pkg_env`, S4 classes) | `APP_MODE=package-deploy`; copy `inst/<subdir>`, prepend `library()` lines, supply data via an RData (mirrors the package's own `deploy_*()` helper). |

## Why not always generate an `app.R`?

Generating `app/app.R` that calls `shinyAppDir(".")` **recurses** (the directory then
contains an `app.R`). Synthesizing an entry is only needed for:
* `package-fn` (the app lives in a package and there is no app directory to copy), or
* a flat `app.R` that calls `runApp()` itself.

For every other directory app, **copying the sources and letting `runApp(dir)` load them**
is the most robust choice.

## recipe: package-deploy (the ShinyStan case)

A package whose Shiny app is a plain directory app that reads package internals
(`inst/ShinyStan/{ui,server,global}.R`; `ui_utils.R`/`server.R` read `shinystan:::.sso_env`).

1. **do not** rely on `library(pkg)` + `pkg:::` at runtime from the bundle -- that is the
   fragile path that failed. Instead mirror the package's own `deploy_shinystan()` helper:
2. copy `inst/<subdir>/*` into `app/`;
3. prepend `library(<deps>);` to `ui.R`/`server.R` (so unqualified calls resolve) using the
   package's own deploy helper's package lists if it has one;
4. save the demo object(s) into `app/sso.RData` and prepend `load("sso.RData")` to `global.R`
   (so the app opens with content and the `pkg:::` fallback branches are never evaluated);
5. install the dependency closure. The package itself is **not** needed at runtime: an S4
   object loads from the RData and its slots resolve **without** the class definition
   (verified). This also drops heavy deps like `rstan`.

Set the knobs: `APP_MODE=package-deploy`, `APP_SUBDIR=ShinyStan`, `UI_LIBS=...`,
`SERVER_LIBS=...`, `DEMO_RDA=data/eight_schools.rda`, `DEMO_OBJECT=eight_schools`,
`DEMO_SAVE_AS=.SHINYSTAN_OBJECT`, `DEMO_RDATA=sso.RData`. See `examples/package-app.shinystan.yml`.

## recipe: package-fn

```
APP_MODE=package-fn
PKG_SUBDIR=.            # package root (contains DESCRIPTION)
ENTRY_FN='library(iSEE); iSEE::iSEE(...)'   # any expression returning a shinyApp object
```

The package's `Depends`/`Imports` seed the closure and the package is installed into `rlib/`.
