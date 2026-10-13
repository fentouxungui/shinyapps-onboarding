# ShinyApps store contract (Route A)

Source of truth: https://github.com/fentouxungui/ShinyApps
(`README.md`, `schemas/*.json`, `catalog/apps.yml`, `.github/workflows/publish-catalog.yml`).

## How the shell runs an app

`appstore.js` extracts the bundle to `apps/<id>/<version>/` and passes `appPath = <bundle>/app`
to the R backend, which runs:

```
.libPaths(c(<private lib>, <shared lib>, .libPaths()))
shiny::runApp('<appPath>', port=..., host='127.0.0.1', launch.browser=FALSE)
```

Consequences:
* the app directory must contain `app.R` **or** `ui.R`+`server.R` (legacy `shinyUI`/
  `shinyServer` also work); `manifest.entry` is **informational** for launching;
* the app directory is the working directory, so **relative asset paths resolve**;
* the app must not require `runApp()` from inside the bundle.

## Bundle artifact (per platform)

```
<id>-<version>-<platform>.zip
  app/               the app (app.R, or ui.R/server.R, plus assets)
  rlib/<Pkg>/        prebuilt dependency closure (pinned to R 4.6.1)
  manifest.json
```

Platforms: `win-x64`, `mac-arm64` (schema also allows `win-arm64`, `mac-x64`, `linux-x64`).

## manifest.json (required fields)

`schema` (=1), `id`, `name`, `version`, `platform`, `entry`, `r_version`, `packages[]`.
`packages[]` items require `name`, `version`, `path`; `source` in `cran|bioc|github|local`.
Optional: `author`, `description`, `homepage`, `license`, `runtime` (`r-shiny`|`py-shiny`),
`min_shell_version`, `notes`.

## Catalog (`catalog/apps.yml` -> `catalog.json`)

Every key **except `repo`** is copied verbatim into `catalog.json`. Each app entry needs at
least `id`, `name`, `repo`; typical fields: `author`, `description`, `homepage`, `docs`,
`email`, `copyright`, `license`, `icon`, `r_version`, `tags`.

`publish-catalog` runs on a 10-minute schedule, on `workflow_dispatch`, on
`repository_dispatch: [bundle-updated]`, and on push to `main` touching `catalog/apps.yml`,
`catalog/render_readme.py`, or `icons/**`. For each entry it reads
`gh api repos/<repo>/releases/latest`, keeps assets named `<id>-*.zip`, parses the platform
from the last two `-` tokens, and records `url`/`size`/`sha256`. It publishes `catalog.json`,
`README.md` and `icons/` to `gh-pages`.

Icon URL pattern: `https://<owner>.github.io/ShinyApps/icons/<id>.png`.

## Versioning rule

The client compares each app's **catalog version** to the installed version. **Any change
must ship under a new tag** (`vX.Y.Z`) or installed users get no `Update`. Re-pushing the
same tag changes `sha256` but not the version, so no `Update` appears.

## Verify

After `publish-catalog`, read back
`https://<owner>.github.io/ShinyApps/catalog.json` and confirm the app's `version`, both
platform artifacts, and their `sha256`.
