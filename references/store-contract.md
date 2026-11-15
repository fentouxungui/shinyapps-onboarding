# ShinyApps store contract (Route A)

Source of truth: https://github.com/fentouxungui/ShinyApps
(`README.md`, `schemas/*.json`, `catalog/apps.yml`, `.github/workflows/publish-catalog.yml`).

## How the shell runs an app

`appstore.js` extracts the bundle to `apps/<id>/<version>/` and passes `appPath = <bundle>/app`
to the R backend, which runs:

```
.libPaths(c(<private lib for r-X.Y>, <shared lib for r-X.Y>, .libPaths()))
shiny::runApp('<appPath>', port=..., host='127.0.0.1', launch.browser=FALSE)
```

Package libraries are scoped by the R runtime ABI (`r-4.6`, `r-4.7`, ...). A bundle
for R 4.6 never loads packages from the R 4.7 library.

Consequences:
* the app directory must contain `app.R` **or** `ui.R`+`server.R` (legacy `shinyUI`/
  `shinyServer` also work); `manifest.entry` is **informational** for launching;
* the app directory is the working directory, so **relative asset paths resolve**;
* the app must not require `runApp()` from inside the bundle.

## Bundle artifact (per platform)

```
<id>-<version>-<platform>-r<abi>.zip   # new bundles, e.g. -r4.6
<id>-<version>-<platform>.zip          # legacy bundles (default ABI)
  app/               the app (app.R, or ui.R/server.R, plus assets)
  rlib/<Pkg>/        prebuilt dependency closure (pinned to one R ABI)
  manifest.json
```

A bundle is built for exactly one R ABI. The template records both the exact
`r_version` and the major.minor `r_abi`; the shell selects the matching runtime
and library. Do not reuse a 4.6 bundle as a 4.7 bundle.

Platforms: `win-x64`, `mac-arm64` (schema also allows `win-arm64`, `mac-x64`, `linux-x64`).

**`rlib/` must not contain base or recommended packages** (`KernSmooth`, `MASS`,
`Matrix`, `survival`, `lattice`, `nlme`, `mgcv`, `boot`, `cluster`, `codetools`,
`foreign`, `rpart`, `spatial`, `class`, `nnet`). The shell's bundled R provides
them. Shipping them shadows the runtime copy and can fail on macOS with
`Library not loaded: /Library/Frameworks/R.framework/.../libRblas.dylib`.

## manifest.json (required fields)

`schema` (=1), `id`, `name`, `version`, `platform`, `entry`, `r_version`, `packages[]`.
`packages[]` items require `name`, `version`, `path`; `source` in `cran|bioc|github|local`.
Optional: `author`, `description`, `homepage`, `license`, `runtime` (`r-shiny`|`py-shiny`),
`r_abi` (major.minor, e.g. `"4.6"`; defaults to the `r_version` minor), `min_shell_version`, `notes`.

For new bundles the workflow writes `r_abi` explicitly. The shell resolves the
runtime by that ABI; a mismatch is a hard installation error, never a fallback.

## Catalog (`catalog/apps.yml` -> `catalog.json`)

Every key **except `repo`** is copied verbatim into `catalog.json`. Each app entry needs at
least `id`, `name`, `repo`; typical fields: `author`, `description`, `homepage`, `docs`,
`email`, `copyright`, `license`, `icon`, `r_version`, `r_abi`, `tags`.
`r_abi` is optional for old entries (derived from `r_version`), but set it for
new entries so the runtime requirement is explicit.

`publish-catalog` runs on a 10-minute schedule, on `workflow_dispatch`, on
`repository_dispatch: [bundle-updated]`, and on push to `main` touching `catalog/apps.yml`,
`catalog/render_readme.py`, or `icons/**`. For each entry it reads
`gh api repos/<repo>/releases/latest`, parses assets named
`<id>-<version>-<platform>.zip` or `<id>-<version>-<platform>-r<abi>.zip`, and records
`url`/`size`/`sha256` in both the legacy flat `artifacts` map and the runtime-aware
`artifacts_by_runtime` map. It publishes `catalog.json`, `README.md` and `icons/` to
`gh-pages`.

Icon URL pattern: `https://<owner>.github.io/ShinyApps/icons/<id>.png`.

## Icons

Always use the app's **own** icon from its upstream repository, not a synthesized one. Look for
`man/figures/logo.png` (pkgdown), `www/logo*.png`, `inst/app/www/img/*logo*.png`,
`inst/assets/*logo*.png`, `docs/logo.png`, or an `<img>` in the README; download it and resize to
a 512x512 PNG (contain on white). Only generate a placeholder when the repo genuinely ships no
logo, and say so in the PR/notes.

## Versioning rule

The client compares each app's **catalog version** to the installed version. **Any change
must ship under a new tag** (`vX.Y.Z`) or installed users get no `Update`. Re-pushing the
same tag changes `sha256` but not the version, so no `Update` appears.

## Verify

After `publish-catalog`, read back
`https://<owner>.github.io/ShinyApps/catalog.json` and confirm the app's `version`, both
platform artifacts, and their `sha256`.
