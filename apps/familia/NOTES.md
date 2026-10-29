# Familia (`familia`)

- **Status:** `active` -- latest build recorded from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/Breeding-Insight/familia
- **Fork:** https://github.com/fentouxungui/familia
- **Release:** https://github.com/fentouxungui/familia/releases/tag/v2.2.0 (`v2.2.0`)
- **Artifacts:**
  - `familia-2.2.0-win-x64.zip` (126 MB)
  - `familia-2.2.0-mac-arm64.zip` (108 MB)
- **Template:** per-app workflow, v3 hardening backported (real startup smoke, verified package-fn install, LEA bundled).

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `auto` |
| `EXTRA_PKGS` | `LEA` (Suggests-only; SNMF/ancestry feature) |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 0 source tarball(s) |
| `SOURCE_REBUILD` | (none) |

## Known limitations

None recorded. LEA is bundled, so the SNMF/ancestry feature works offline; LEA is compiled and increases bundle size and build time moderately.

## Debug log

- 2026-10-22: backfilled from the v0.1.0 release assets.
- 2026-10-29: fork synced to upstream 2.2.0; workflow hardened after the
  Copilot review (tag checkout, real startup check, verified package-fn install,
  LEA bundled). v2.2.0 built (run 40800465738) on both platforms; the Windows
  bundle installs and runs through the ShinyApps client.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.