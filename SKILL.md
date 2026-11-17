---
name: shinyapps-onboarding
description: Onboard a Shiny-app GitHub repository into the ShinyApps desktop app store (fentouxungui/ShinyApps) end to end - feasibility assessment, fork, a per-repo prebuilt bundle workflow, tag-driven Actions build that attaches bundles to the tag's GitHub Release, catalog entry and icon, and an upstream pull request. Use when the user wants to publish or "上架" a Shiny app repo to the ShinyApps store, add a desktop bundle for a Shiny app, or reuse the hardened "Route A" prebuilt-bundle onboarding.
---

# ShinyApps onboarding

Publish any Shiny-app repository to the **ShinyApps** desktop app store using the hardened
**"Route A"** route: a per-repo GitHub Actions workflow builds prebuilt desktop bundles
(Windows `win-x64`, macOS `mac-arm64`, R 4.6.1) on a `v*` tag push and attaches them to
that tag's GitHub Release; a catalog entry + icon make the app installable without
rebuilding the store shell.

**Skill version:** `2026.11.17.8` (see `VERSION`). Canonical source:
<https://github.com/fentouxungui/shinyapps-onboarding> (`main`).

## Mandatory version gate (read first)

**No workflow work starts from a loaded/imported skill until it is verified against
the canonical latest.**

Applies to:

- creating a new per-app `.github/workflows/build-app-bundle.yml`;
- upgrading, patching, renaming, or reviewing an existing workflow;
- changing this skill's workflow template or workflow rules.

Minimum preflight:

1. Locate the skill actually loaded by the agent (not a stale clone or memory).
2. Fetch canonical `main`; read its `VERSION` and commit SHA.
3. Compare the loaded `VERSION` and commit (git checkout) or `SKILL.md` +
   `assets/build-app-bundle.yml` SHA-256 (imported copy).
4. If stale or dirty: update/re-import, reload the session, and re-read the skill files.
5. Record the verified commit and `VERSION` in the app record and PR.

If the latest version cannot be verified, stop and ask; do not proceed on an old
version. Full procedure and commands: `references/skill-version-policy.md`.

Read `references/skill-version-policy.md` first, then
`references/failure-modes.md`, `references/app-shapes.md`,
`references/store-contract.md`, `references/release-hardening.md` and
`references/independent-platform-releases.md` before touching a workflow.

## When to use

- publish / "上架" a Shiny app GitHub repo to the ShinyApps store;
- add a prebuilt desktop bundle so users need no local R install;
- reproduce the onboarding done for iSEE, UCSCXenaShiny, spatialLIBD, beeRapp,
  CSBB-Shiny, SeuratExplorer, scConvertShiny, shinyCircos-V2.0, UpSetR-shiny, bestDEG,
  GraphBio, splitKbCompare, ShinyStan and shiny-genome-stats.

Do **not** use for non-Shiny apps, or apps that need a server-side engine the bundle
cannot ship (give a feasibility caveat).

## App shapes

- **flat** -- `app.R`, or `ui.R`+`server.R` (incl. legacy `shinyUI`/`shinyServer`): copy
  the sources; the runtime runs the directory. Do not synthesize an entry.
- **package-fn** -- an R package whose exported function returns a `shinyApp` object:
  `ENTRY_FN` is that call; install the package.
- **package-deploy** -- an app directory inside an R package that reads package internals:
  copy the app files, prepend `library()` lines, supply data via an RData (mirror the
  package's own `deploy_*()` helper). Do **not** use `library(pkg)` + `pkg:::` + `runApp`.

`assets/build-app-bundle.yml` handles all three (`APP_MODE: auto|flat|package-fn|package-deploy`).

## Procedure

0. **Version gate (mandatory).** Complete `references/skill-version-policy.md`
   before any other step. Do not use an unverified skill.
1. **Feasibility (gate).** Confirm the app runs from a directory or matches a package
   recipe; that dependencies resolve on CRAN/Bioconductor (archived via `ARCHIVE_URLS`,
   extra repos via `EXTRA_REPOS`); that no unshippable runtime engine is required (else
   record it in `APP_NOTES`); that no successful start depends on a first-launch
   download (plan a build-time prefetch -- see `references/startup-data.md`); and the
   license. For a heavy app (many modules, a large `data/`/`db/`, GitHub-only packages,
   `BSgenome.*`), also size the bundle and plan build-time patches before the first
   build -- see `references/heavy-apps.md`. Proceed only when high.
2. **Fork** the upstream repo.
3. **Generate + push** `.github/workflows/build-app-bundle.yml` from
   `assets/build-app-bundle.yml`, filling the `env:` block -- every `__PLACEHOLDER__`,
   including `APP_MODE`, `STRICT_VERSION`, `STRICT_DEPS`, `CRAN_SNAPSHOT`,
   `PANDOC_VERSION`, `MACOS_BREW_DEPS`, `PKG_VERSION_PACKAGES` and
   `PKG_VERSION_SUFFIX`. Unsubstituted `__X__` values fall back to safe defaults.
   Use the standard filename; do **not** prefix it with the app id.
4. **Tag** `vX.Y.Z` and push the tag. The standard workflow builds on `push: tags`
   (`v*`), canonicalizes the tag, creates the tag's Release if none exists, and
   attaches the bundles. Do not add a `release: published` trigger: the Release the
   workflow creates would start a second identical build. A manual dispatch with an
   existing tag is the retry path and attaches only to that tag's existing Release;
   it never creates one. Create the tag with `git push` (the driver does this):
   GitHub's Release UI can create a tag without emitting a `push` event, so if the
   tag was created there, run the workflow manually against it.
5. **Onboard**: append the entry from `assets/catalog-entry.yml` to
   `ShinyApps/catalog/apps.yml`, add `ShinyApps/icons/<id>.png` (from the upstream repo's own logo), push.
   The generated entry points at the fork while testing; after the upstream PR is
   merged and upstream pushes its own `v*` tag (the workflow creates the Release),
   change `repo:` to the upstream repository so the store follows upstream, not the fork.
6. **Open the upstream PR** (CI-only; see `references/pr-template.md`).
7. **Record it** with `scripts/record-app.ps1 -AppId <id> -Fork <owner>/<repo> -Upstream
   <owner>/<repo> -Tag <tag>`: it snapshots the workflow **at the tag**, the asset sizes and
   the commit SHAs, then scaffolds `meta.yml` + `NOTES.md`. Fill `decisions` and the debug
   log, then run `scripts/validate-apps.ps1` and `scripts/build-app-index.ps1`. Record failed
   and rejected attempts too (`status: abandoned|rejected`); they are the most useful evidence.

Fast path: run `scripts/onboard-shiny-app.ps1` (steps 2-6), then `record-app.ps1` for step 7.

## Hard rules

- **Latest-skill gate.** Before creating, upgrading, reviewing or patching any
  workflow, verify the loaded skill against canonical `main` and record the commit;
  do not proceed on a stale/imported snapshot. See
  `references/skill-version-policy.md`.
- Store `id` must be lowercase `^[a-z0-9][a-z0-9-]*$` and equal the release asset prefix.
  New bundles use `<id>-<version>-<platform>-r<abi>.zip` (for example `-r4.6`);
  legacy unsuffixed `<id>-<version>-<platform>.zip` assets remain supported.
- The app must run from a directory; never rely on `pkg:::` + `runApp()` from the bundle.
- Pin to a **supported R ABI** (currently R 4.6.1 / ABI 4.6). Record both
  `r_version` (exact) and `r_abi` (major.minor) in `manifest.json`; never mix
  binaries built for different R minors.
- **Build with the shell's portable R, not the CI framework R.** The template
  downloads the same `portable-r` release the shell ships and runs the app closure
  with its `Rscript`; `setup-r` is only for build tooling. Installing app packages
  with the runner's framework R produces `.so` files that reference
  `/Library/Frameworks/R.framework` and fail inside ShinyApps. Pass the script
  path positionally (`Rscript script.R`); `Rscript` does not accept R's `-f` flag
  (macOS treats `-f` as a filename; Windows can crash). On macOS, do not set
  `R_PROFILE` to an empty string: that disables portable R's `.portable` site
  profile, which is what rewrites CRAN binary `.so` files to `@rpath`.
  After the portable-R setup, invoke the absolute `"$PORTABLE_RSCRIPT"` in later
  steps; a bare `Rscript` can resolve to the runner's framework R or a shim,
  producing `The system cannot find the path specified` (exit 255) before any R
  code runs. On Windows, keep `R_HOME` empty and let Rscript self-locate: a set
  `R_HOME` (even a correct path) can fail once the portable bin is on
  `GITHUB_PATH`. Write `R_HOME=` empty to `GITHUB_ENV` on Windows; macOS keeps
  the portable `R_HOME`. Do not add the portable bin to `GITHUB_PATH`: a
  forward-slash drive entry can make Windows `where`/R `Sys.which` exit 255.
  Check `make`/`gcc` with shell `command -v`, not R `Sys.which`. Do not read
  that 255 as a missing `make`/`gcc`.
- **Never ship base/recommended packages in `rlib`.** The shell's bundled R provides
  `KernSmooth`, `MASS`, `Matrix`, `survival`, `lattice`, `nlme`, `mgcv`, `boot`,
  `cluster`, `codetools`, `foreign`, `rpart`, `spatial`, `class`, `nnet`, etc.
  Shipping them shadows the runtime copy; on macOS the copied binary can reference
  the builder's `/Library/Frameworks/R.framework` and fail on users' Macs. The
  template asserts this and the macOS audit flags R.framework paths.
- **Re-sign macOS Mach-O files after portable-R patching.** Portable R's `.portable`
  wrapper rewrites CRAN `.so` load commands after `install.packages()` but does not
  re-sign them. The template runs a `codesign --force --sign -` + `codesign --verify`
  pass over every Mach-O file in `bundle/` before zipping. Without it, macOS kills R
  with `EXC_BAD_ACCESS (SIGKILL (Code Signature Invalid))` / `Namespace CODESIGNING,
  Code 2 Invalid Page` when the package is loaded. Do not remove that step.
- **Bump the version on every change** -- same version = no client `Update`.
- **Tag policy.** With `STRICT_VERSION: "auto"` (default) a package tag must equal
  `DESCRIPTION` `Version`; a repo without a `DESCRIPTION` uses the tag as the store
  version. Use `on` to require a `DESCRIPTION`, and `off` only for a deliberate
  mismatch documented in `APP_NOTES` and the PR. Never ship a silent mismatch.
- **One workflow filename, including migrations.** Always
  `.github/workflows/build-app-bundle.yml`; do not prefix it with the app id. The
  archive uses this name, the recorder defaults to it, and the PR template expects
  it. An existing per-app workflow such as
  `.github/workflows/<id>-build-app-bundle.yml` must be renamed to
  `build-app-bundle.yml` when the app is re-onboarded or its workflow is next
  changed: `git mv` it (or add the new file and delete the old one) in the same
  commit, never keep both. Do not rewrite the historical `workflow_path` in
  `apps/<id>/meta.yml`; it records the path used by that release. The next
  `record-app.ps1` run uses the standard path (its default).
- **Tag-push trigger, never `release: published`.** Use `on.push.tags: ['v*']` plus
  `workflow_dispatch` with a required `tag` input. The workflow creates the Release
  for a new tag; listening for `release.published` as well would start a second
  identical build, and `release: published` alone makes a plain tag push a no-op.
  If the repo does not use `v` tags, change the pattern and the `resolve`
  canonicalization together.
- **Immutable releases, one canonical tag.** Refuse to overwrite a published release
  asset. The preflight must use `gh release view --repo`, and only an explicit
  `release not found` / HTTP 404 may be treated as a missing release; other lookup
  failures abort. Upload with `gh release upload` and no `--clobber`; do not use
  `softprops/action-gh-release` (it has no `release_id`/`allowUpdates`, and a
  `tag_name` that differs from the existing tag silently creates a new Release).
- **Manual runs attach, tag pushes own the Release.** `workflow_dispatch` must fail
  when the tag has no Release; it must never create one. Only a `push` event, or a
  `workflow_call` with `allow_create_release: true`, may create the missing Release.
- **Release platforms independently.** A matrix `bundle` job has one aggregate
  result. The release job must use `always()` (plus `resolve` success), tolerate
  missing platform artifacts, and publish only the platforms that built. Upload
  only the platform zips; keep `meta-*`/`deps-*`/checksum files as Actions
  artifacts. ShinyApps `publish-catalog` derives `sha256` from GitHub's asset
  digest and ignores non-zip assets. For a missing-platform retry, use the Run
  Bundle workflow and the `platforms`/`workflow_call` pattern in
  `references/independent-platform-releases.md`.
- **Least privilege.** The build job is `contents: read`; only the release job is
  `contents: write`. Remove unused `GITHUB_PAT`/`GITHUB_TOKEN` env entries.
- **One version source.** A `resolve` job takes the dispatch input or `github.ref_name`,
  strips `refs/tags/` and a leading `v`, trims whitespace, and verifies the tag
  exists; checkout, version and upload all use `needs.resolve.outputs.tag`. Never
  concatenate refs. Require the tag to equal `DESCRIPTION` when a package is present.
- **Record the built commit.** After checkout, compare `git rev-parse HEAD` with the
  tag commit and write `SOURCE_COMMIT` into the build metadata; do not use
  `GITHUB_SHA`, which may refer to the workflow ref.
- **Supported macOS runners.** `macos-14` was retired on 2026-11-02; use
  `macos-15` for the arm64 bundle. Keep the app's own macOS minimum in the
  documentation, not in `runs-on:`.
- **Keep release assets small.** Publish the platform ZIPs only; keep
  `meta-*`/`deps-*`/checksum files as Actions artifacts. ShinyApps
  `publish-catalog` derives `sha256` from GitHub's asset digest and ignores
  non-zip assets, so extra Release files add no store value and can collide when
  a second platform is added later.
- **Pin and validate dependencies.** Use a CRAN snapshot, write the resolved lock
  before installation, and verify the installed closure in a clean child process.
  Present the lock as an enforced artifact, not a post-install inventory.
- **Fail loud.** Required and transitive dependencies missing from the configured
  repositories fail the build (`STRICT_DEPS: "on"`); list genuinely optional packages
  in `SOFT_PKGS` instead of letting them disappear.
- **Use the app's own icon.** Follow `references/icon-sourcing.md`: repository logo files -> README/HTML -> pkgdown -> the project site linked from the repo About/README -> generate only as a last resort. Reject platform logos, screenshots and badges; never overwrite an already-correct icon.
- **PR quality is part of onboarding.** Every upstream PR must use
  `references/pr-template.md`: explain what ShinyApps is, why the workflow exists, the
  exact diff scope (one YAML file, no app code), the impact (Actions minutes only when a
  `v*` tag is pushed, credit), what the maintainer must do, and an explicit opt-out.
  One-line "adds a workflow" PRs are not acceptable and damage the store's reputation.
- **Verify** `catalog.json` shows the app with the expected artifacts + `sha256`
  (Windows-only apps have no mac asset; document the deviation).
- **Patched packages need unique versions.** If you vendor dylibs into a package (Cairo,
  gdtools, ...) or otherwise modify it per app, set `PKG_VERSION_PACKAGES` +
  `PKG_VERSION_SUFFIX` so each app's copy has a distinct version; allocate it with
  `scripts/next-pkg-version.ps1`. Never reuse a suffix, and never patch only the newest
  app -- every app that ships the package must differ (`references/special-packages.md`).
- **Every attempt gets a record.** `apps/<id>/` holds the exact generated workflow and the
  debug log. `ShinyApps/catalog/apps.yml` remains the only source of truth for what is
  listed; `status` in `meta.yml` only describes build/authorization state. A rejected app
  stays in `apps/` with `status: rejected` and a "do not redistribute" banner.

## Reliability

The workflow ships a **`Smoke test`** step that starts the built bundle with `shiny::runApp()` in a child
process (clean library: `rlib` + base R), waits for the server and requests `/`; it fails unless an HTML
page comes back, and prints the child's output on failure. Constructing the app object (`shinyAppDir()`)
is not enough -- a `ui` function, an `onStart` hook or a resource-loading error can fail only once the
server runs. See `references/failure-modes.md`. The child must explicitly exclude
`.Library.site` and the portable-R harness: use
`.libPaths(c(rlib, .Library), include.site = FALSE)` and
`callr::r_bg(..., env = c(R_LIBS_SITE = "", R_LIBS_USER = "", R_LIBS = ""))`.
Otherwise macOS reports `smoke: unexpected library paths: .../harness-root/harness`
and the app exits before serving. Turn it off with `SMOKE: "off"` for apps that need network
at startup.

A **module that the user explicitly opens** may fetch its own large data on first use
(one artifact at a time, into a user-writable library, with progress and a readable
failure) -- this is the only allowed exception to the no-startup-download rule. Conditions
and a reference implementation: `references/runtime-downloads.md`. The shell moves
`app/rlib` into a shared library after install, so a per-user library outside the app
directory survives and vendored dylibs travel with their package -- keep the user library
**appended** to `.libPaths()`.

**Apps that fetch a database at first launch** (a reference DB, taxonomy, annotation bundle)
must not do it from the bundle: the user may be offline and R's default `download.file` timeout
(60 s) aborts a large download mid-stream, so the app errors on start. Generate that data at
build time and ship it inside `app/`, so the app's own "file exists?" guard is satisfied and it
never downloads. Point the workflow's `PREFETCH_SCRIPT` at a repo R script; the template runs it
inside the bundled `app/` with `rlib/` on `.libPaths()` before zipping. For a heavy dump, generate
once in a separate job and pass it as an artifact. Recipe: `references/startup-data.md`.

The template builds the dependency graph from the **source** index, uses `pkgType="both"`
(binary then source), runs a fix-up loop, load-validates seed packages from `rlib/`,
excludes base and recommended packages, audits macOS binaries for XQuartz/Homebrew
links, and re-signs every Mach-O file in `bundle/` after portable-R patching. It also fails
when any `library()`/`require()`/`pkg::` name in the app sources is missing from `rlib/`,
because the smoke test renders the UI once but never clicks a module -- a package loaded
inside a click handler otherwise stays invisible until a user presses the button.

Archived and GitHub-only packages go through `ARCHIVE_URLS` and must be named in
`FORCED_PKGS`; a failed archive install aborts the build. A local source install with
`dependencies = FALSE` does not resolve dependencies: install the full CRAN/Bioc
transitive closure of each archive's declared deps before the archive itself. The
template's `install_archive()` does this; an older workflow missing it will fail even
for pure-R archives. Build-time config patches (absolute author paths, disabling a
module that cannot ship) go in `PATCH_SCRIPT`, which runs inside `bundle/app/` before
zipping. Recipes: `references/heavy-apps.md`. macOS portability:
`references/macos-portability.md`.

## Field lessons (batch CRAN sweep)

- The template uses `__APP_ID__`, `__APP_SUBDIR__`, `__ENTRY_FN__`, ... placeholders. When generating a
  workflow by hand, replace **every** placeholder; an unsubstituted `__ENTRY_FN__` fails only at smoke time.
- `APP_MODE: "auto"` selects `flat` only when the repo has no `DESCRIPTION`. If the app lives in
  `inst/<dir>` (or any subdirectory of a package), set `APP_MODE: "flat"` plus `APP_SUBDIR` explicitly.
- YAML quoting: an `ENTRY_FN` containing double quotes must use single quotes inside the YAML string,
  e.g. `ENTRY_FN: "local({ source('app.R') })"`, or the workflow never triggers.
- `package-fn` works only when the exported function **returns** a `shinyApp` object. A launcher that calls
  `runApp()` blocks and makes smoke time out after the 300 s budget -- use `SMOKE: "off"` only after the log
  shows `Listening on http://127.0.0.1:...` (evidence the app really starts), or build a `shinyapps/app.R`
  adapter that returns the object.
- `flat` bundles only the app directory. Paths in `ENTRY_FN` are relative to that directory, not the repo root.
- macOS: an OpenMP symbol error (`___kmpc_barrier`, `kohonen.so`, ...) is fixed by
  `SOURCE_REBUILD: "<pkg>"`. XQuartz-only links (`Cairo` via `ggrastr`) are **not** a dead
  end: vendor the X11 dylibs into the package's `libs/` with `install_name_tool` + ad-hoc
  `codesign` (ScRDAVis v1.1.2 ships both platforms this way, +15-30 MB). `tcltk`/Tcl-Tk is
  still hard -- guard or drop that module. Source packages needing openssl/hdf5 use
  `MACOS_BREW_DEPS`. Never put `dylibbundler` in a loop -- it hangs; see
  `references/macos-portability.md`.
- **macOS `Code Signature Invalid` after a green smoke test.** The bundle installs and the
  smoke test passes, but on a user Mac R dies with `EXC_BAD_ACCESS (SIGKILL (Code Signature
  Invalid))` / `Namespace CODESIGNING, Code 2 Invalid Page` while loading a package. Portable
  R's `.portable` wrapper patched that package's `.so` after installation without re-signing
  it. Verify `rlib/` with `codesign --verify` before publishing, and run the template's
  `Re-sign macOS binaries` step; a failing file often lives in the shell's shared library,
  so `codesign --verify` on the `.app` alone can still pass. Shared-library dedup can keep
  the bad package when an update ships the same version, so existing installs may need the
  package re-signed or cleared.
- **A new R minor means a new bundle.** Do not treat `4.7` as a drop-in for `4.6`:
  binary packages, Bioconductor releases and `.so`/`.dll` files are version-specific.
  Keep the old `r-A.B` runtime for existing installs, build a new bundle with
  `r_abi: "A.B"`, and let the shell select the runtime. The template writes `r_abi`
  from `R_VERSION`; never hand-edit it to make a bundle look compatible.
- With the tag-push trigger, poll `actions/runs?event=push`, match
  `.github/workflows/build-app-bundle.yml`, and select the run whose `head_branch`
  is the tag (a manual or default-branch push must not be mistaken for it).
- `cran/*` repos are read-only mirrors: onboard the fork but do not open an upstream PR.
- `ARCHIVE_URLS` accepts a monorepo tarball whose package sits in a subdirectory (BPCells in
  `r/`): the template locates the single `DESCRIPTION` and installs that package's Imports
  first. A tarball with several packages fails on purpose -- pass a package tarball.
- **Pure-R GitHub archives still need their transitive R deps.** No `src/` and no
  `NeedsCompilation` does not mean "no dependency work": `jjPlot -> tidyverse`,
  `ggunchull -> alphahull/dbscan/polyclip`, `jjAnno -> ggiraphExtra/magick` all have large
  closures. Local `install.packages(..., repos = NULL, dependencies = FALSE)` installs only
  the package. The template now expands each archive's declared deps with
  `tools::package_dependencies(..., recursive = TRUE)` before installing the archive; for an
  older workflow, add the archive's direct CRAN deps to `EXTRA_PKGS` as a belt-and-suspenders
  fix. Reproduce with `R CMD INSTALL --no-clean-on-error` and read `00install.out`.
- Publish **Windows-only** when a macOS dependency cannot be made portable (see
  `references/macos-portability.md`): remove the macOS matrix entry and record it in
  `APP_NOTES`; do not ship a mac zip that cannot start.
- **Use supported GitHub macOS runners.** `macos-14` was retired on 2026-11-02;
  jobs using it fail before checkout with
  `The configuration 'macos-14-arm64-us-default' is not supported`. Use
  `macos-15` for the arm64 bundle (`macos-15-intel` only for Intel), and never
  copy `macos-14` from an old workflow or example.

## Field lessons (upstream PR review: FielDHub, Familia)

- **Sync the fork before tagging.** Familia's fork was 13 commits behind upstream: its
  `DESCRIPTION` said 2.0.0 while upstream and CRAN were 2.2.0. The PR diff still showed one file
  (GitHub compares the merge base), so the gap was invisible in review. Merge upstream into the
  fork before building, and verify `DESCRIPTION` at the checked-out ref, not in the browser.
- **One version source, and check out the tag.** Concatenating `release.tag_name + ref_name +
  inputs.tag` produced `2.2.0v2.2.0`; a manual run from `main` produced `mainv2.2.0`. The
  `resolve` job now takes `inputs.tag || github.ref_name`, strips `refs/tags/` and `v`,
  verifies the tag exists, and every later step uses `needs.resolve.outputs.tag`. A manual
  run builds that tag; a bad tag fails before any build, never ships default-branch code.
- **Construction is not startup.** `shinyAppDir()` returns the app object without running the
  server; a `ui` function, `onStart` hook or resource-loading error passes silently. Both a human
  maintainer and Copilot rejected this. The template now runs `shiny::runApp()` and GETs `/`.
- **package-fn: a CRAN copy can mask a failed local install.** When the app is on CRAN, the
  dependency closure installs it; if the checked-out source then fails, `install.packages()` only
  warns and the directory check passes, so the CRAN build ships under the new tag. Exclude the
  package from the closure, `unlink()` any existing copy, install the source, and compare the
  installed `DESCRIPTION` version with the source.
- **Suggests-only packages can hide a user-facing feature.** Familia's SNMF/ancestry tab needs
  LEA, which is only in `Suggests`: the bundle built, but the app told users to install LEA. Check
  `Suggests` during the feature inventory; add such packages to `EXTRA_PKGS` (LEA is
  Bioconductor-only, has no system requirements and compiles on both runners), or document the
  feature as unavailable in `APP_NOTES` and the PR.
- **The icon must be the app's own identity.** Familia's store icon was the Breedverse logo
  (`breedverse_logo.png`) although the repo ships `inst/app/www/familia_logo.png`. Pick the file
  named for the app, then render the 512 px result and look at it; a parent-program or dependency
  logo is a wrong icon, not a style choice.
- **Reply with evidence after review.** State point by point what changed and how it was verified:
  the test tag, both platforms built, the real startup check passed, and the Windows bundle
  installed through the ShinyApps client launches and runs. Then explain releases: pushing a
  `v*` tag starts the build automatically and the workflow creates/attaches that tag's
  Release; a manual run with an existing tag attaches to its existing Release only and
  cannot create one. Keep the PR to one workflow file
  (`.github/workflows/build-app-bundle.yml`) and answer bot reviews in one summary comment
  (resolve the inline threads).

## Field lessons (shiny-genome-stats)

- **Use the standard workflow filename.** `.github/workflows/build-app-bundle.yml`
  is the convention; the old `<id>-build-app-bundle.yml` name is legacy and should
  not be used for new onboarding. An existing prefixed file is renamed when the app
  is re-onboarded or its workflow is next changed (see the filename hard rule).
  GitHub shows the workflow name, not the filename, so a shared filename causes no
  confusion across apps.
- **One trigger, and it must be the tag push.** The earlier review chose
  `release: published` because adding `push: tags` alongside it double-builds the
  same tag. That avoided the duplicate but made a plain tag push a no-op, and the
  Release the workflow created re-triggered it. The corrected model is `push: tags`
  only (no `release: published`), with manual dispatch attaching to an existing
  Release. Keep exactly one automatic trigger; never both.
- **Copilot/reviewer findings worth fixing proactively.** Remove unused
  `GITHUB_PAT`/`GITHUB_TOKEN` env entries; keep the top-level permissions at
  `contents: read` with `contents: write` only on the release job; resolve the
  version without concatenating `release.tag_name`, `ref_name`, and `inputs.tag`;
  and check out the tag being built.
- **README is part of the PR.** Add a short "Desktop version" section: users can
  install/run in the ShinyApps store without installing R or configuring an
  environment. Link the ShinyApps download page, recommend **Manage Apps → All**
  → search → **Install**, and keep **Install from Bundle** as the manual fallback.
- **After the upstream merge, switch the catalog to upstream.** Test against the
  fork release while onboarding; once the upstream release exists, set
  `catalog/apps.yml` `repo:` to the upstream repository and verify the vX.Y.Z
  Windows/macOS assets resolve from upstream.

## Security

`scripts/onboard-shiny-app.ps1` reads the GitHub token via `git credential fill` into the
process environment only and performs fork/push/tag/PR on the user's behalf; it
requires a `repo`+`workflow` token. Review before running. The workflow creates the
tag's Release after a green build. The CI build job is `contents: read`; only the
release job may write.

**Release hardening.** Besides the smoke test, the template canonicalizes and validates
the tag, makes manual runs attach-only, enforces the tag/version policy, keeps releases
immutable, uses clean-library smoke (only `rlib` + base R on `.libPaths()`), fails fast
on dependencies, supports an optional `CRAN_SNAPSHOT` pin and optional
`PANDOC_VERSION`, and publishes `*.sha256`, `meta-*.json` and `deps-*.json`. Checklist:
`references/release-hardening.md`.

## Files

- `VERSION` - human-readable skill version; must match canonical `main`.
- `assets/build-app-bundle.yml` - hardened multi-mode workflow template.
- `assets/catalog-entry.yml` - catalog entry template.
- `scripts/onboard-shiny-app.ps1` - parameterized driver for steps 2-6.
- `scripts/validate-apps.ps1`, `scripts/build-app-index.ps1`, `scripts/new-app-record.ps1`
  - record checks, index generation and scaffolding (`apps/README.md`).
- `apps/<id>/` - per-app archive: exact workflow, `meta.yml`, `NOTES.md`.
- `references/skill-version-policy.md`, `references/app-shapes.md`,
  `references/failure-modes.md`, `references/store-contract.md`,
  `references/startup-data.md`, `references/release-hardening.md`,
  `references/independent-platform-releases.md`, `references/heavy-apps.md`,
  `references/macos-portability.md`, `references/runtime-downloads.md`,
  `references/special-packages.md`, `references/pr-template.md`.
- `examples/` - historical v1 workflows for flat, package-fn and package-deploy apps.
  They predate the v5.5 trigger/release fixes and are annotated do-not-copy; use
  `assets/build-app-bundle.yml` for new onboarding.
