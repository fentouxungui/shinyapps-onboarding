# shinyapps-onboarding

Reusable, **battle-tested** tooling to publish any Shiny-app GitHub repository to the
[ShinyApps](https://github.com/fentouxungui/ShinyApps) desktop app store, end to end:

```
feasibility -> fork -> bundle workflow -> tag / GitHub Actions release
            -> catalog entry + icon -> (optional) upstream pull request
```

Route A: a per-repo GitHub Actions workflow builds **prebuilt desktop bundles**
(Windows `win-x64`, macOS `mac-arm64`, pinned to R 4.6.1) and attaches them to a GitHub
Release; a catalog entry + icon make the app installable **without rebuilding the store
shell**. The same route powers iSEE, UCSCXenaShiny, spatialLIBD, beeRapp, CSBB-Shiny,
SeuratExplorer, scConvertShiny, shinyCircos-V2.0, UpSetR-shiny, bestDEG, GraphBio,
splitKbCompare and ShinyStan.

## Contents

| Path | Purpose |
|---|---|
| `assets/build-app-bundle.yml` | Hardened **multi-mode** bundle workflow (drop into `.github/workflows/`, fill `env:`) |
| `assets/catalog-entry.yml`     | Catalog entry for `ShinyApps/catalog/apps.yml` |
| `scripts/onboard-shiny-app.ps1`| Parameterized driver for steps 2-6 (`-StrictVersion`, `-CranSnapshot`, `-PandocVersion`) |
| `scripts/validate-apps.ps1`    | Structural checks for `apps/<id>/` records (CI: `.github/workflows/validate-apps.yml`) |
| `scripts/build-app-index.ps1`  | Regenerate `apps/INDEX.md` |
| `scripts/new-app-record.ps1`   | Scaffold a new app record from `apps/_template` |
| `scripts/record-app.ps1`       | Snapshot a released app (workflow at the tag, sizes, SHAs) into `apps/<id>/` |
| `scripts/check-upstream.ps1`   | Drift report: upstream commits/releases, fork behind, workflow changes |
| `scripts/build-dashboard.ps1`  | Render the maintenance board from `site/status.json` |
| `apps/<id>/`                   | Exact workflow + `meta.yml` + debug log for each onboarded or attempted app |
| `references/app-shapes.md`     | The 5 app shapes and how each is handled |
| `references/failure-modes.md`  | Real failures and their fixes -- read this first |
| `references/startup-data.md`   | First-launch data downloads: generate at build time into the bundle |
| `references/store-contract.md` | Bundle/manifest/catalog contract and `publish-catalog` |
| `references/release-hardening.md` | Tag/version policy, release-safety checklist, reviewer boundary |
| `references/heavy-apps.md`     | Many modules / many dependencies / large data: census, size budget, build-time patches |
| `references/macos-portability.md` | XQuartz/Homebrew dylib failures and the remediation ladder |
| `references/runtime-downloads.md` | When a user-triggered module download is acceptable (and how) |
| `references/pr-template.md`    | Structure for the upstream pull request |
| `examples/`                    | Real working workflows (flat, package-fn, package-deploy) |

## App shapes

The workflow auto-detects most cases (`APP_MODE: auto`):

- **flat** -- the repo is the app: `app.R`, or `ui.R`+`server.R` (incl. legacy
  `shinyUI`/`shinyServer`). Sources are copied verbatim; the runtime runs the directory.
- **package-fn** -- an R package whose exported function returns a `shinyApp` object;
  `ENTRY_FN` is that call, and the package is installed into `rlib/`.
- **package-deploy** -- the app is a directory inside an R package that reads package
  internals; the app files are copied, `library()` lines prepended, and data supplied via
  an RData (mirrors the package's own `deploy_*()` helper).

See [references/app-shapes.md](references/app-shapes.md) for detection and recipes.

## Prerequisites

- `git` on PATH and a GitHub credential for `https://github.com` with the
  **`repo` + `workflow`** scopes (the `workflow` scope is required to push a
  `.github/workflows/` file). The script reads it via `git credential fill`.
- A 512x512 PNG icon for the app.
- **Git-LFS gotcha**: a global `filter.lfs.*` config can make `clone`/`fetch` hang or
  abort. Disable it per command with
  `-c filter.lfs.process= -c filter.lfs.smudge= -c filter.lfs.clean= -c filter.lfs.required=false`
  (the script already does this).

## Step 1 - feasibility (do this first)

Proceed only if all hold:

1. **Contract**: the app runs from a directory (has `app.R`, or `ui.R`+`server.R`), or is
   an R package handled by the package-fn / package-deploy recipes. It must not require
   `runApp()` from inside the bundle.
2. **Dependencies**: `library()`/`pkg::` usage resolves against CRAN/Bioconductor. Flag
   GitHub-only deps; handle CRAN-archived ones via `ARCHIVE_URLS`.
3. **Runtime**: no dependence on a shared server, a local daemon, or a system engine the
   bundle cannot ship (LaTeX for dynamic PDF, a remote service, a private conda env).
   List every such feature as a **known limitation** in `APP_NOTES`.
4. **License**: record it (some upstreams declare none - disclose redistribution).
5. **First-launch data**: if the app downloads a database on start (taxonomy, reference DB), plan a build-time prefetch into the bundle -- see [references/startup-data.md](references/startup-data.md).

## Steps 2-6 - run the driver (or copy the workflow and do it by hand)

```powershell
.\scripts\onboard-shiny-app.ps1 -ShinyAppsOwner <your-gh-username> `
  -Upstream <owner>/<repo> -AppId <app-id> -AppName "<App Name>" `
  -AppAuthor "<authors>" -AppLicense <SPDX> -AppHomepage "<url>" `
  -AppMode flat -AppSubdir "." -AppTags "a,b,c" `
  -StrictVersion auto -CranSnapshot 2026-10-01 -PandocVersion 3.1.11 `
  -IconPath .\icon.png -Tag v0.1.0 -WatchRelease -OpenPR
```

Omit `-Tag` to use the package `Version` when a `DESCRIPTION` exists. Omit
`-CranSnapshot` for live CRAN, and `-PandocVersion` for apps that do not render R Markdown.

## Version and release policy

The default template follows the maintainer-review checklist in
[references/release-hardening.md](references/release-hardening.md): the build starts from
the exact tag, a package tag must equal `DESCRIPTION` `Version`, there is a single tag
trigger, and an existing release asset is never overwritten.

| `STRICT_VERSION` | Behaviour | When |
|---|---|---|
| `auto` (default) | Enforce tag = `DESCRIPTION` `Version` when a `DESCRIPTION` exists; otherwise the tag is the store version | Packages and flat repos |
| `on` | Require a `DESCRIPTION` and enforce equality; fail without one | Package repos with a known root |
| `off` | Tag is the store version; no comparison | Deliberate re-packaging; explain in `APP_NOTES` and the PR |

`CRAN_SNAPSHOT` pins CRAN inputs to a Posit Package Manager date. `STRICT_DEPS: "on"`
(default) turns a missing required or transitive dependency into a build failure instead
of a silent drop; use `SOFT_PKGS` for genuinely optional packages. `PANDOC_VERSION`
installs and checks Pandoc for report-rendering apps (Pandoc and LaTeX are not bundled;
PDF output still needs LaTeX locally).

## Built-in smoke test

The workflow includes a **`Smoke test`** step: after building, it unzips the bundle, puts
`rlib/` on `.libPaths()`, and loads the app the way the ShinyApps shell does -- in a bounded child
process (`callr::r` with a timeout) that cannot hang and prints the exact R error on failure. A failed
start blocks the release. Toggle with `SMOKE: "on"|"off"` and `SMOKE_TIMEOUT_SEC` (default 300).

The smoke test builds the UI only. A separate check fails the build when any
`library()`/`require()`/`pkg::` name in the app sources is missing from `rlib/`, which
catches packages loaded inside click handlers. It is still not a substitute for clicking
through each module in the real ShinyApps shell.

## Reliability playbook (why this template is hardened)

The workflow builds the dependency graph from the **source** index, installs
per-package with `pkgType="both"` (binary, falling back to source), runs a **fix-up loop**
over installed `DESCRIPTION`s, **load-validates** every required seed package from `rlib/`,
excludes base and recommended packages, and on macOS audits binaries for non-portable
XQuartz/Homebrew links. Archived/GitHub-only packages are installed from `ARCHIVE_URLS` and
verified against `FORCED_PKGS`; `PATCH_SCRIPT` applies build-time config patches inside
`bundle/app/`. Heavy-app playbook:
[references/heavy-apps.md](references/heavy-apps.md); macOS dylibs:
[references/macos-portability.md](references/macos-portability.md). The smoke test runs with `R_LIBS_USER`/`R_LIBS_SITE` cleared and
only `rlib` + base R on `.libPaths()`, so a runner library cannot mask a missing bundle
dependency. The build job is `contents: read`; only the release job may write, and it
publishes `*.sha256`, `meta-*.json` and `deps-*.json`. Full list:
[references/failure-modes.md](references/failure-modes.md).

**First-launch downloads.** An app that downloads a database on start (e.g. PhyloProfile's NCBI taxonomy) fails in the bundle -- offline, and R's 60 s `download.file` timeout aborts a large dump. Pre-generate that data at build time and ship it inside `app/` (the workflow's `PREFETCH_SCRIPT` hook, or a dedicated job for heavy dumps). Recipe: [references/startup-data.md](references/startup-data.md).

**Two rules that prevent the most common "it looks done but isn't":**

1. **Always bump the version** (`vX.Y.Z`) for any change. Installed clients compare the
   catalog version to the installed one; re-pushing the same tag produces no `Update`.
2. **Verify the catalog**, don't assume: read back
   `https://<owner>.github.io/ShinyApps/catalog.json` and confirm the app's `version`, both
   platform artifacts, and their `sha256`.

## App records (`apps/`)

Every app that was onboarded -- listed, pending, rejected or abandoned -- gets a folder
under `apps/<id>/` with the generated workflow **as it ran**, a `meta.yml` (status, tag,
sizes, non-default decisions) and a `NOTES.md` (symptom -> cause -> fix -> verification).
`apps/INDEX.md` is generated. The record is a **snapshot**: `ShinyApps/catalog/apps.yml`
remains the only source of truth for what is actually listed, and rejected apps carry a
"do not redistribute" banner. Rules and workflow: [apps/README.md](apps/README.md).

A weekly GitHub Actions job (`weekly-upstream-check.yml`) compares each snapshot with its
fork and upstream and publishes a maintenance board to GitHub Pages: last build, upstream
commits/releases since then, fork sync status and workflow drift. It never edits `apps/`.
Enable Pages once (Settings -> Pages -> GitHub Actions) to publish it.

## Store side

`ShinyApps/catalog/apps.yml` is the single registry; every key except `repo` is copied into
`catalog.json`. `publish-catalog` discovers each app's **latest Release assets** by the
`<id>-` filename prefix and publishes `catalog.json` + `icons/` to `gh-pages`.

## Security

The driver reads your GitHub token with `git credential fill` into the process environment
only (never written to disk) and performs fork/push/tag/release/PR **on your behalf**.
Review the script before running it, and keep the token scoped to `repo` + `workflow`.

## License

MIT - see [LICENSE](LICENSE).
