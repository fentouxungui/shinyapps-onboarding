# Release hardening and version policy (the exmort review)

This checklist comes from a maintainer review of an upstream PR. It is the difference
between "CI produced a zip" and "a release channel a maintainer can accept".

## The seven review points

1. **Tag = source = version.** Build from the exact tag; fail if `DESCRIPTION` `Version`
   does not equal the tag (minus `v`). A store tag is not free-form when the repo is a
   package.
2. **One trigger, immutable assets.** Only tag pushes (or a manual run with an explicit
   tag) may publish. A second trigger such as `release: published` can double-build.
   Refuse to overwrite an existing release asset.
3. **Dependencies must fail loudly.** A required or transitive dependency missing from the
   configured repositories is a hard error, not a `WARN` followed by silently dropping the
   package. Pin CRAN inputs to a snapshot date and publish the resolved package list.
4. **Clean-library smoke.** The smoke test must use only the bundle's `rlib` plus base R.
   Set `.libPaths(c(rlib, .Library))` in the child and fail when any other path is present;
   otherwise a runner library can mask a missing bundle dependency.
5. **Report toolchain.** If the app renders R Markdown, install and check Pandoc in CI.
   Pandoc and LaTeX are not part of the bundle; document the runtime requirement (PDF
   additionally needs LaTeX).
6. **Least privilege + metadata.** Build jobs are read-only; only the publish job has
   `contents: write`. Publish SHA-256 files, build/source metadata and a dependency lock.
   Do not rewrite existing release notes.
7. **Shell testing boundary.** A CI bundle is not a tested desktop install. Test the real
   ShinyApps shell on Windows/macOS separately; do not claim shell E2E from a green CI
   smoke, which starts the server and requests `/` but is not an installed store run.

## The version-policy decision

Use `STRICT_VERSION` (default `auto`):

| Value | Behaviour | When |
|---|---|---|
| `auto` | If `DESCRIPTION` exists at `PKG_SUBDIR`, tag must equal `Version`; if there is no `DESCRIPTION`, skip the check and use the tag as the manifest version. | Default for packages and flat repos. |
| `on` | Require `DESCRIPTION`; tag must equal `Version`. Fail if no `DESCRIPTION` is found. | Package repos where the package root is known. |
| `off` | Never compare; tag is the store version. | Deliberate repackaging, or a mono-repo where the package root cannot be identified. Record the reason in `APP_NOTES` and the PR. |

**Recommendation:** set the tag to the package version (`Version: 0.1.1` -> `v0.1.1`) and
leave `auto`. It keeps the upstream Release, the bundle manifest and the store catalog
aligned, and it avoids the exact objection raised in review. Use `off` only when there is
no `DESCRIPTION` or when the store version intentionally differs; never silently ship a
mismatch.

For a repo with no `DESCRIPTION` (a flat `app.R` / `ui.R`+`server.R` repo), `auto` skips
the check and the tag is the only version source. Choose a semver tag deliberately and
bump it for every change.

## Where the policy lives

- `assets/build-app-bundle.yml` - the workflow template. `STRICT_VERSION`,
  `STRICT_DEPS`, `CRAN_SNAPSHOT` and `PANDOC_VERSION` are in its `env:` block; an
  unsubstituted `__PLACEHOLDER__` falls back to the safe default at build time.
- `scripts/onboard-shiny-app.ps1` - driver with `-StrictVersion`, `-StrictDeps`,
  `-CranSnapshot` and `-PandocVersion`; it writes `APP_MODE`, derives the tag from
  `DESCRIPTION` when `-Tag` is omitted, and refuses a mismatch unless
  `-StrictVersion off`.
- This reference - policy, review checklist, and no-DESCRIPTION guidance.

Keep the three aligned: a template change without the driver update (or the reverse)
leaves generated workflows with placeholders that only fall back by accident.

## Reviewer-facing boundary

Addressing the workflow does not grant store-distribution permission. Keep the
technical review and the authorization question separate in the PR; offer to remove the
listing if the maintainer prefers.
