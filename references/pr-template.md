# Pull request template (store onboarding)

Never open a bare "adds a workflow" PR. Maintainers receive many CI PRs and will close
low-context ones. Every PR must answer, in this order:

1. **What is ShinyApps?** Community-run desktop store for Shiny apps; prebuilt bundles
   (Windows x64 / macOS arm64, pinned R) so users need no R install. Link the store repo
   and `catalog.json`.
2. **Why this PR?** The app is listed in the store and needs a reproducible prebuilt
   artifact. State explicitly that only one YAML file is added and no application code,
   `DESCRIPTION`, tests, or data change.
3. **What the workflow does.** Numbered: install deps into a private library; build both
   platforms; smoke-test that the app starts; attach zips to a Release on tag.
4. **Impact on the maintainer.** No source changes; no maintenance burden; Actions minutes
   only on tag pushes (free standard runners for public repos, ~10-20 min/platform);
   discoverability and credit with a link back to the repo.
5. **What the maintainer needs to do.** Review the single file, merge (or request a
   different filename/branch), optionally push a tag; offer to do it for them.
6. **Opt-out.** "If you would rather not have this, close the PR and I will remove the
   store entry. No hard feelings."
7. **Thanks**, naming the app.

Keep it plain Markdown, no marketing fluff, no claims that the author must accept.
Use the app name consistently. Reuse this template verbatim, substituting the app name.

## Repairing existing PRs

If earlier PRs were opened with a one-line body, update them with
`PATCH /repos/{owner}/{repo}/pulls/{number}` (title + body). Personalize per repo; do not
paste an unmodified wall of text that names the wrong app.