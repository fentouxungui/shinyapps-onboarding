# exmort (`exmort`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/shanlong-who/exmort
- **Fork:** https://github.com/fentouxungui/exmort
- **Release:** https://github.com/fentouxungui/exmort/releases/tag/v0.1.1 (`v0.1.1`)
- **Artifacts:**
  - `exmort-0.1.1-win-x64.zip` (158 MB)
  - `exmort-0.1.1-mac-arm64.zip` (145 MB)
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

> If `status` is `rejected` or `withdrawn`: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| `APP_MODE` | `flat` |
| `EXTRA_PKGS` | (none) |
| `SOFT_PKGS` | (none) |
| `ARCHIVE_URLS` | 0 source tarball(s) |
| `SOURCE_REBUILD` | gdtools |

## Known limitations

Report rendering requires Pandoc (checked at build time). PDF output additionally requires a LaTeX installation (not bundled).

## Debug log

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.