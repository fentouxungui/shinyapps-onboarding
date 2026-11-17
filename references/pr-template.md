# Pull request template (store onboarding)

Never open a bare "adds a workflow" PR. Maintainers receive many CI PRs and will close
low-context ones. Every PR must answer, in this order:

1. **What is ShinyApps?** Community-run desktop store for Shiny apps; prebuilt bundles
   (Windows x64 / macOS arm64, pinned R) so users need no R install. Link the store repo
   and `catalog.json`.
2. **Why this PR?** The app is listed in the store and needs a reproducible prebuilt
   artifact. State explicitly that only `.github/workflows/build-app-bundle.yml` is
   added and no application code, `DESCRIPTION`, tests, or data change.
3. **What the workflow does.** Numbered: install deps into a private library; build both
   platforms; smoke-test that the app starts; on a `v*` tag push, create the tag's Release
   if needed and attach the zips (a manual run only attaches to an existing Release).
4. **Impact on the maintainer.** No source changes; no maintenance burden; Actions minutes
   only when a tag is pushed (free standard runners for public repos, ~10-20
   min/platform); discoverability and credit with a link back to the repo.
5. **What the maintainer needs to do.** Review the single file
   `.github/workflows/build-app-bundle.yml`, merge (or request a different filename/branch),
   then push a `vX.Y.Z` tag; the workflow creates the tag's Release. Offer to do it for them.
6. **Opt-out.** "If you would rather not have this, close the PR and I will remove the
   store entry. No hard feelings."
7. **Thanks**, naming the app.

Keep it plain Markdown, no marketing fluff, no claims that the author must accept.
Use the app name consistently. Reuse this template verbatim, substituting the app name.

## Replying after review

A review (human or GitHub Copilot) needs evidence, not "done". Reply in one comment that
answers each finding and then states how it was verified:

- **Skill version** -- state the canonical `shinyapps-onboarding` commit and `VERSION`
  used to generate or review this workflow.
- **Version** -- one source: the `resolve` job takes `inputs.tag || github.ref_name`,
  strips `refs/tags/` and a leading `v`, requires the tag to exist, and every later step
  uses `needs.resolve.outputs.tag`; no `1.6.0v1.6.0` or `mainv2.2.0`. The tag must equal
  `DESCRIPTION` when a package is present.
- **Manual runs** -- `actions/checkout` uses `ref: ${{ needs.resolve.outputs.tag }}`; a
  supplied tag builds that tag's source, an unknown tag fails before the build, and a
  manual run without an existing Release fails instead of creating one.
- **Startup** -- the smoke test starts `shiny::runApp()` in a child process and requests `/`
  (HTTP 200 + HTML); `shinyAppDir()` only constructed the object.
- **package-fn install** -- the app package is excluded from the CRAN closure, any existing
  copy is removed, the checked-out source is installed, and its installed `DESCRIPTION`
  version is compared with the source.
- **Optional features** -- name the Suggests-only packages you bundled (e.g. LEA for SNMF) or
  the feature you left out.
- **Verification** -- the tag you built, both platforms green, and: "I installed the Windows
  bundle through the ShinyApps desktop client; it launches and runs normally."
- **Release instructions** -- push the `vX.Y.Z` tag; the workflow builds, creates
  that tag's Release if needed, and attaches
  `<id>-<version>-win-x64-r<abi>.zip` / `<id>-<version>-mac-arm64-r<abi>.zip`.
  ShinyApps derives `sha256` from GitHub's asset digest; meta/checksum files stay
  as Actions artifacts. Platforms are released independently: a failed platform
  does not block the successful one. To complete a partially released tag, run
  the Run Bundle workflow for the
  missing platform; a direct manual Build dispatch attaches to an existing
  Release only and does not create one.
- **Scope** -- one workflow file, no application code, and an offer to adjust the filename or
  branch.

Answer automated review findings in the summary comment and resolve the inline threads; do not
reply to each bot comment separately. Push the fixes and re-run the workflow so the reviewer
sees a green build.

## Repairing existing PRs

If earlier PRs were opened with a one-line body, update them with
`PATCH /repos/{owner}/{repo}/pulls/{number}` (title + body). Personalize per repo; do not
paste an unmodified wall of text that names the wrong app.