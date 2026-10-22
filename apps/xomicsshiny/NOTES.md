# xOmicsShiny (`xomicsshiny`)

- **Status:** `pending` -- both platform bundles build and pass smoke; the author has been
  asked (issue) and the app is **not** in the ShinyApps catalog yet.
- **Upstream:** https://github.com/interactivereport/xOmicsShiny
- **Fork:** https://github.com/fentouxungui/xOmicsShiny
- **Release:** https://github.com/fentouxungui/xOmicsShiny/releases/tag/v3.0.2 (`v3.0.2`)
- **Artifacts:** `xomicsshiny-3.0.2-win-x64.zip` (946 MB),
  `xomicsshiny-3.0.2-mac-arm64.zip` (916 MB)
- **Template:** pre-hardening personal skill (v3 era); the workflow carries custom
  compatibility steps that are not in the current template.

## Why it is packaged this way

| Setting | Value | Reason |
|---|---|---|
| `APP_MODE` | `flat` | root `app.R` + `global.R`; 24 modules are sourced from the app directory |
| `EXTRA_PKGS` | 76 packages | scanned every module file, so plugin features (WGCNA, Mfuzz, DRomics, GSEA/ORA, network, pathview) have their dependencies |
| `SOFT_PKGS` | `metabaser Mfuzz` | metabaser is not on CRAN and its trigger file `db/human/metabase_maps_genesymbols.gmt` is absent (feature auto-disabled); Mfuzz needs `tcltk`/XQuartz on macOS |
| `ARCHIVE_URLS` | PCSF `master` tarball | PCSF is no longer in Bioconductor 3.23; `topGO` was added as its dependency |
| `SOURCE_REBUILD` | `gdtools` | CRAN's macOS binary hard-links XQuartz (`libXrender`) |
| config patch | `server_dir` -> `.` | upstream `config.csv` shipped `D:/customProjects_NEW/...` |
| `SMOKE_TIMEOUT_SEC` | 900 | 76 packages, slow first namespace load |

## Debug log

| # | Symptom | Root cause | Fix | Verified by |
|---|---|---|---|---|
| 1 | macOS: `non-portable dylib references: Cairo.so, gdtools.so` | CRAN macOS binaries link `/opt/homebrew` and `/opt/X11` | `SOURCE_REBUILD=gdtools`; removed `ggrastr` (Cairo) and made Rasterize vector-only | audit clean, smoke OK |
| 2 | `dylibbundler` loop did not finish for ~50 min | recursive dependency copying hangs | abandoned `dylibbundler`; dropped the XQuartz-only package instead | job finishes |
| 3 | macOS audit "passed" while broken | regex anchored with `^`, but `otool -L` output is tab-indented | unanchored match; audit now fails on real offenders | broken package detected |
| 4 | PCSF module failed although smoke was green | the portability rewrite deleted the `ARCHIVE_URLS`/fix-up blocks; PCSF is loaded only inside `observeEvent()` | restored both blocks; archive install is fatal on error; `FORCED_PKGS` check | `forced packages ok: PCSF` |
| 5 | version assets named `mainv3.0.1` | version built by concatenating three refs | single `inputs.tag \|\| github.ref_name` | asset names `xomicsshiny-3.0.1-...` |
| 6 | TF/Mfuzz modules dead on macOS | `tcltk` needs XQuartz | Mfuzz listed as soft; module disabled on macOS only | Windows smoke + manual test |

## Known limitations

- `metabaser` feature unavailable (not on CRAN, no trigger file) -- recorded in `APP_NOTES`.
- macOS: Mfuzz soft-clustering disabled (`tcltk`/XQuartz); Rasterize draws vector output.
- `biomaRt`, `enrichR`, `pathview` need network; the rest works offline.
- Bundle is ~950 MB per platform because 297 MB of demo data is included.

## Reuse notes

Copy the dependency-census approach (every module, not only `global.R`), the `config.csv`
patch, and the macOS ladder. Specific to this app: its 24-module layout, KEGG map assets,
and PCSF's archived tarball.
