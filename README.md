# shinyapps-onboarding

Reusable tooling to publish **any Shiny-app GitHub repository** to the
[ShinyApps](https://github.com/fentouxungui/ShinyApps) desktop app store, end to end:

```
feasibility  ->  fork  ->  bundle workflow  ->  tag / GitHub Actions release
             ->  catalog entry + icon  ->  (optional) upstream pull request
```

It uses the store's **"Route A"** model: a per-repo GitHub Actions workflow builds
**prebuilt desktop bundles** (Windows `win-x64`, macOS `mac-arm64`, pinned to R 4.6.1)
and attaches them to a GitHub Release; a catalog entry + icon in the store make the app
installable **without rebuilding the store shell**. The same route already powers iSEE,
UCSCXenaShiny, spatialLIBD, beeRapp, CSBB-Shiny, SeuratExplorer, scConvertShiny,
shinyCircos-V2.0, UpSetR-shiny, GraphBio, splitKbCompare and ShinyStan.

## Contents

| Path | Purpose |
|---|---|
| `assets/build-app-bundle.yml` | Generic **dual-mode** bundle workflow (drop into `.github/workflows/`, fill the `env:` block) |
| `assets/catalog-entry.yml`     | Catalog entry for `ShinyApps/catalog/apps.yml` |
| `scripts/onboard-shiny-app.ps1`| Parameterized driver for steps 2-6 (fork → workflow → tag → release → catalog → PR) |
| `references/store-contract.md` | Bundle/manifest/catalog contract and how `publish-catalog` works |
| `references/pr-template.md`    | Structure for the upstream pull request |
| `examples/`                    | Two real, working workflows: a flat app and a package app |

## Two app shapes

* **flat** — the repo *is* the app: `app.R`, or `ui.R` + `server.R` (+ `global.R`).
  Sources are copied verbatim and a tiny entry `app/app.R` is generated.
* **package** — the app lives inside an **R package** (e.g. `inst/<subdir>/`). The package
  **and** its dependency closure are installed into `rlib/`, and the entry either is a
  custom `ENTRY_B64` or `shiny::shinyAppDir(system.file("<APP_SUBDIR>", package="<pkg>"))`.

`APP_MODE` defaults to `auto` (package if a `DESCRIPTION` is present, else flat).

## Prerequisites

* `git` on PATH and a GitHub credential for `https://github.com` with the
  **`repo` + `workflow`** scopes (the `workflow` scope is required to push a
  `.github/workflows/` file). The script reads it via `git credential fill`.
* A 512x512 PNG icon for the app.
* **Git-LFS gotcha**: a global `filter.lfs.*` config can make `clone`/`fetch` hang or abort.
  Disable it per command with
  `-c filter.lfs.process= -c filter.lfs.smudge= -c filter.lfs.clean= -c filter.lfs.required=false`
  (the script already does this).

## Step 1 - feasibility (do this first)

Proceed only if all hold:

1. **Contract**: the entry returns a `shinyApp` object and never calls `runApp()`.
2. **Dependencies**: `library()`/`pkg::` usage resolves against CRAN/Bioconductor. Flag
   GitHub-only deps; handle CRAN-archived ones via `ARCHIVE_URLS`.
3. **Runtime**: no dependence on a shared server, a local daemon, or a system engine the
   bundle cannot ship (e.g. LaTeX for dynamic PDF, a remote service, a private conda env).
   List every such feature as a **known limitation** in `APP_NOTES` and the PR.
4. **License**: record it (some upstreams declare none - disclose redistribution).

## Steps 2-6 - run the driver

Flat app:

```powershell
.\scripts\onboard-shiny-app.ps1 -ShinyAppsOwner <your-gh-username> `
  -Upstream jhelvy/splitKbCompare -AppId splitkbcompare -AppName splitKbCompare `
  -AppAuthor "John Helveston" -AppLicense MIT `
  -AppHomepage "https://github.com/jhelvy/splitKbCompare" `
  -AppDocs "https://github.com/jhelvy/splitKbCompare#readme" `
  -AppCopyright "(c) 2020 John Helveston" -AppTags "keyboard,layout,comparison" `
  -AppSubdir "." -ExtraPkgs "rmarkdown" `
  -Exclude "rsconnect,images/raw,images/overlays.ai" `
  -IconPath .\icon.png -Tag v0.1.0 -WatchRelease -OpenPR
```

Package app (the ShinyStan case):

```powershell
.\scripts\onboard-shiny-app.ps1 -ShinyAppsOwner <your-gh-username> `
  -Upstream stan-dev/shinystan -AppId shinystan -AppName ShinyStan `
  -AppAuthor "Jonah Gabry, Duco Veen, Stan Development Team" -AppLicense "GPL-3.0-or-later" `
  -AppHomepage "https://mc-stan.org/shinystan/" -AppDocs "https://mc-stan.org/shinystan/" `
  -AppMode package -PkgSubdir "." -AppSubdir "ShinyStan" -ExtraRepos "https://stan-dev.r-universe.dev" `
  -EntryB64 "<base64 of your app/app.R>" -SoftPkgs "rstan" `
  -IconPath .\icon.png -Tag v0.1.0 -WatchRelease -OpenPR
```

Prefer doing it by hand? Fork the repo; add `.github/workflows/<id>-build-app-bundle.yml`
(from `assets/build-app-bundle.yml`, `env:` filled); push a `vX.Y.Z` tag; append the entry
from `assets/catalog-entry.yml` to `ShinyApps/catalog/apps.yml`; drop the icon at
`ShinyApps/icons/<id>.png`; push; open the upstream PR.

## How the workflow works

Per platform (`win-x64`, `mac-arm64`) on **R 4.6.1**:

```
<id>-<version>-<platform>.zip
  app/app.R         generated entry (returns a shiny.appobj; never runApp())
  app/...           upstream sources copied verbatim (flat mode)
  rlib/<Pkg>/       prebuilt binary dependency closure (package itself included in package mode)
  manifest.json     schema/id/version/platform/entry/r_version/packages/notes
```

* **Triggers**: push of a `v*` tag, `release: published`, or manual `workflow_dispatch`.
* **Dependency seed**: package mode reads `Depends`/`Imports` from `DESCRIPTION`; flat mode
  auto-extracts `library()`/`require()`/`pkg::`. Both are closed transitively over
  CRAN/Bioconductor; `EXTRA_REPOS` adds repos (e.g. `https://stan-dev.r-universe.dev`).
* **Archived packages**: list CRAN-Archive tarball URLs in `ARCHIVE_URLS`.
* **Exclusions**: `EXCLUDE` drops source-only assets (AI/SVG, screenshots) to keep the bundle lean.
* **`SOFT_PKGS`** are installed when a build is available but never fail the build (disclosed in `notes`).

## Store side

`ShinyApps/catalog/apps.yml` is the single registry; every key except `repo` is copied into
`catalog.json`. `publish-catalog` discovers each app's **latest release assets** by the
`<id>-` filename prefix and publishes `catalog.json` + `icons/` to `gh-pages`. So once the
entry + icon are pushed, the app appears in the store automatically.

## Security

The driver reads your GitHub token with `git credential fill` into the process environment
only (never written to disk) and performs fork/push/tag/release/PR **on your behalf**.
Review the script before running it, and keep the token scoped to `repo` + `workflow`.

## License

MIT - see [LICENSE](LICENSE).
