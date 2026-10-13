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


## golem apps (package-fn)

A `golem` app's `run_app()` **returns** the app object
(`golem::with_golem_options(shinyApp(app_ui, app_server), golem_opts = list(...))`); it does not
call `runApp()` at build time. So a golem app is a **package-fn**:
`ENTRY_FN='library(pkg); pkg::run_app(...)'`. Disable any external backend through the golem
options -- e.g. `pkg::run_app(with_mongo = FALSE)` for hexmake (the MongoDB "My hexes" tab is
then hidden). If a transitive dependency (`hexSticker`/`ggimage`/`rvg`) pulls **`gdtools`**,
set `SOURCE_REBUILD=gdtools` (its CRAN macOS binary links XQuartz/Homebrew).

## Auto-printing app objects

Some packages ship an S3 generic that **returns** a `shiny.appobj` and relies on the console
auto-printing it to launch (e.g. `explor()` / `explor.PCA()`). That is contract-compliant: the
generated entry just calls the function and returns the value. Supply the object the app needs
(e.g. a demo `FactoMineR::PCA(...)` result).

## Frameworks and generators are NOT apps

Do **not** try to bundle these as-is -- they have no single runnable app:

| Package | What it is | What would be needed |
|---|---|---|
| **teal** | framework; `init()` returns a `teal_app` **list**, run as `shiny::shinyApp(app$ui, app$server)`; needs `modules` | bundle a **demo** built from `teal` + `teal.modules.general` + `teal_data()` |
| **learnr** | tutorial framework; `run_tutorial()` renders an `.Rmd` tutorial into an app | bundle **one tutorial** (or an `app.R` that renders it) |
| **ShinyCell / ShinyCell2** | **generators**: `makeShinyApp()`/`makeShinyFiles()` write an app dir from single-cell data | generate an app from a **bundled example dataset** at build time, then bundle that output |

For these, the feasibility step must say so and propose bundling a concrete demo/tutorial app
instead of the framework itself.

### A package whose app directory does `library(<pkg>)`

Sometimes a package ships its app as a **directory inside `inst/`** and the app's `global.R` does
`library(<pkg>)` (e.g. PhyloProfile's `inst/PhyloProfile/global.R`). Treat it as a **flat** app --
`APP_MODE=flat`, `APP_SUBDIR=inst/<subdir>` -- and add `<pkg>` to `EXTRA_PKGS` so the package is
installed for that call. (Do **not** use package-deploy here: package-deploy installs only the
closure, not the app package.)
