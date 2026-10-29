# FielDHub (`fieldhub`)

- **Status:** `active` -- latest build recorded from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/DidierMurilloF/FielDHub
- **Fork:** https://github.com/fentouxungui/FielDHub
- **Release:** https://github.com/fentouxungui/FielDHub/releases/tag/v0.1.6 (`v0.1.6`)
- **Artifacts:**
  - `fieldhub-0.1.6-win-x64.zip` (102 MB)
  - `fieldhub-0.1.6-mac-arm64.zip` (97 MB)
- **Template:** per-app workflow, hardened after the upstream PR review (single-source version, tag checkout, real startup smoke).

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `auto` |
| `EXTRA_PKGS` | (none) |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 0 source tarball(s) |
| `SOURCE_REBUILD` | (none) |

## Known limitations

(none recorded; the workflow did not declare APP_NOTES)

## Debug log

- 2026-10-22: backfilled from the v0.1.0 release assets.
- 2026-10-28: v0.1.6 built with the hardened workflow (build run 40645447608).
  The smoke test starts the app with `shiny::runApp()` and requests `/`; both
  platforms passed. The upstream PR was updated after the maintainer's review
  (version selection, tag checkout, startup check).

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.