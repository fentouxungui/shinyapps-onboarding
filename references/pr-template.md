# Upstream PR structure (fill-in template)

Title:
`Add a GitHub Actions workflow publishing prebuilt desktop app bundles (ShinyApps store)`

Body sections (English):

1. **Summary** - "one GitHub Actions workflow"; CI-only; no application code changed.
2. **What is ShinyApps?** - desktop store, pinned R 4.6.1, on-demand install; list apps already carried.
3. **Why this matters for <APP>** - tie to the app's actual audience; note existing
   hosting (shinyapps.io / runGitHub / Docker) stays unchanged.
4. **What this workflow does** - triggers, matrix, build steps, artifact layout.
5. **Contract compliance** - show the generated `app/app.R` entry; state that upstream
   sources are byte-for-byte unchanged.
6. **Dependency closure** - the auto-detected set; note any archived/GitHub deps.
7. **Known limitation (honest disclosure)** - anything that will not work offline
   (missing engine/service). State which parts still work.
8. **Testing** - link the fork workflow, the built Release (with asset names + sizes),
   and the public `catalog.json` entry.
9. **How maintainers can test it** - install the shell, find the card, Install -> Run.
10. **Impact and maintenance** - CI cost; no side effects; offer `workflow_dispatch`-only,
    artifact-instead-of-Release, SHA-pinning, concurrency.
11. **Licensing** - confirm upstream license unchanged; note redistribution of binaries.
12. **If accepted** - update catalog `repo`/`homepage` to the official repo; zero-maintenance channel.
13. **Checklist** - CI-only; builds end-to-end; entry returns `shinyApp`; closure derived;
    limitation disclosed.

Also produce a short Chinese "提交前提示" (Base/Head branch, one-file diff, license note,
the honest disclosure) for the user, kept outside the PR body.

Model the tone on the existing ShinyApps PRs (iSEE, UCSCXenaShiny, shinyCircos, GraphBio).
