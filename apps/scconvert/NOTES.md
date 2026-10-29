# scConvertShiny (`scconvert`)

- **Status:** `active` -- latest build recorded from the published release; see `meta.yml` for provenance.
- **Upstream:** https://github.com/fentouxungui/scConvertShiny
- **Fork:** https://github.com/fentouxungui/scConvertShiny
- **Release:** https://github.com/fentouxungui/scConvertShiny/releases/tag/v0.1.3 (`v0.1.3`)
- **Artifacts:**
  - `scconvert-0.1.3-win-x64.zip` (211 MB)
  - `scconvert-0.1.3-mac-arm64.zip` (196 MB)
- **Template:** per-app workflow, fail-loud app-tarball version guard.

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

Windows: scConvert conversion relies on `hdf5r`; the CRAN Windows `hdf5r` bundles HDF5 1.12.x whose `H5Fclose` can fail at GC (documented scConvert limitation).

## Debug log

- 2026-10-22: backfilled from the v0.1.2 release assets.
- 2026-10-28: v0.1.2 shipped a bundle without `scConvertShiny`
  (`there is no package called 'scConvertShiny'`): `DESCRIPTION` was 0.1.1
  while the tag was v0.1.2, so the tarball lookup matched nothing and the local
  install was skipped silently. Fixed by bumping `DESCRIPTION` to 0.1.3 and
  adding a fail-loud guard; v0.1.3 built (run 40638959971) on both platforms.

## Reuse notes

Use the archived workflow and `meta.yml` decisions as a reference; redo the dependency
census for a different app instead of copying these values.