# Upstream PR structure (fill-in template)

Title:
`Add a GitHub Actions workflow publishing prebuilt desktop app bundles (ShinyApps store)`

Body sections (English):

1. **Summary** - one workflow; CI-only; no application code changed.
2. **What is ShinyApps?** - desktop store, pinned R 4.6.1, on-demand install; list apps already carried.
3. **Why this matters for <APP>** - tie to the app's actual audience; note existing hosting
   (shinyapps.io / runGitHub / Docker) stays unchanged.
4. **What this workflow does** - triggers, matrix, build steps, artifact layout.
5. **How it maps to the app's own shape** - flat directory vs package-fn vs package-deploy
   (mirror any `deploy_*()` helper the project already has); state that upstream sources are
   byte-for-byte unchanged.
6. **Dependency closure** - the auto-derived set; note archived/GitHub/Bioconductor deps and
   the binary->source handling.
7. **Known limitation (honest disclosure)** - anything that will not work offline (missing
   engine/service) or needs the network. State which parts still work.
8. **Testing** - link the fork workflow, the built Release (asset names + sizes), and the
   public `catalog.json` entry.
9. **How maintainers can test it** - install the shell, find the card, Install -> Run.
10. **Impact and maintenance** - CI cost; no side effects; offer `workflow_dispatch`-only,
    artifact-instead-of-Release, SHA-pinning, concurrency.
11. **Licensing** - confirm upstream license unchanged; note redistribution of binaries.
    If the upstream declares **no** license, raise it explicitly and ask.
12. **If accepted** - point the catalog `repo`/`homepage` at the official repo; zero-maintenance channel.
13. **Checklist** - CI-only; builds end-to-end; app runs from its directory (no `runApp()`);
    closure derived; limitation disclosed.

Also produce a short Chinese "提交前提示" (Base/Head branch, one-file diff, license note,
and the honest disclosure), kept outside the PR body.

Before opening the PR, **bump the version and rebuild** so the linked Release/test evidence
is real and current. Model the tone on the existing ShinyApps PRs (iSEE, UCSCXenaShiny,
shinyCircos, GraphBio).
