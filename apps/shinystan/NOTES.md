# ShinyStan (`shinystan`)

- **Status:** `active` -- backfilled from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/stan-dev/shinystan
- **Fork:** https://github.com/fentouxungui/shinystan
- **Release:** https://github.com/fentouxungui/shinystan/releases/tag/v0.3.0 (`v0.3.0`)
- **Artifacts:**
  - `shinystan-0.3.0-win-x64.zip` (110 MB)
  - `shinystan-0.3.0-mac-arm64.zip` (106 MB)
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

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

ShinyStan packaged as a plain ui.R/server.R app (same technique as shinystan::deploy_shinystan): the app files are bundled, library() lines are prepended, and the built-in eight_schools demo is provided via sso.RData at startup. Load your own MCMC output through the app's normal load/paste workflow. Model fitting is out of scope (ShinyStan visualizes an existing posterior sample).

## Debug log

Backfilled on 2026-10-22 from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.