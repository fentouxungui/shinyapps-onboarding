# ShinyApps store contract (Route A)

Source of truth: https://github.com/fentouxungui/ShinyApps
(see `README.md`, `schemas/*.json`, `catalog/apps.yml`, `.github/workflows/publish-catalog.yml`).

## Bundle artifact (per platform)

```
<id>-<version>-<platform>.zip
  app/app.R          entry (returns a shiny.appobj; never runApp())
  app/...            the app's own sources and assets, copied verbatim
  rlib/<Pkg>/        prebuilt binary dependency closure (pinned to R 4.6.1)
  manifest.json      bundle manifest (schema below)
```

Platforms currently built: `win-x64`, `mac-arm64` (schema also allows `win-arm64`,
`mac-x64`, `linux-x64`).

## manifest.json (required fields)

`schema` (=1), `id`, `name`, `version`, `platform`, `entry` (e.g. `app/app.R`),
`r_version`, `packages[]`. `packages[]` items require `name`, `version`, `path`
(e.g. `rlib/Seurat`); `source` is one of `cran|bioc|github|local`.
Optional: `author`, `description`, `homepage`, `license`, `runtime`
(`r-shiny`|`py-shiny`), `min_shell_version`, `notes`.

## Catalog (`catalog/apps.yml` -> `catalog.json`)

`apps.yml` is the single hand-maintained registry. Every key **except `repo`** is
copied verbatim into `catalog.json`. Each app entry needs at least `id`, `name`,
`repo`; typical fields: `author`, `description`, `homepage`, `docs`, `email`,
`copyright`, `license`, `icon`, `r_version`, `tags`.

`publish-catalog` (`.github/workflows/publish-catalog.yml`) runs on a 10-minute
schedule, on `workflow_dispatch`, on `repository_dispatch: [bundle-updated]`, and on
push to `main` touching `catalog/apps.yml`, `catalog/render_readme.py`, or `icons/**`.
For each entry it calls `gh api repos/<repo>/releases/latest`, keeps assets whose name
starts with `<id>-` and ends with `.zip`, parses `platform` from the last two `-`
tokens, takes the version from `tag_name` (minus `v`), and records
`url`/`size`/`sha256` (from the asset `digest`). It then publishes `catalog.json`,
`README.md` and `icons/` to `gh-pages`. An app with no published release is kept but
marked unavailable.

Icon URL pattern: `https://<owner>.github.io/ShinyApps/icons/<id>.png`.

## Runtime / entry contract

- Pin packages to **R 4.6.1** (the shell runtime).
- Entry returns a `shinyApp` object; **never** call `runApp()`.
- The shell sets the app directory as the working directory, so relative paths resolve.
- The store shell is `shinyelectron` (multi-app-store branch); app bundles never rebuild it.
