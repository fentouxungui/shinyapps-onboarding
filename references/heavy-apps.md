# Heavy apps: many modules, many dependencies, large data

A "heavy" app is one where a naive workflow produces a zip that builds, passes the
smoke test and still fails for the user. The two field cases behind this file are
xOmicsShiny (76 bundled packages, 297 MB demo data, ~950 MB per platform) and ScRDAVis
(87 packages, 10 of them GitHub-only, two BSgenome references of 731 MB + 650 MB).

Signals to check at feasibility time:

- more than ~30 declared packages, or a `modules/` / `R/` fan-out;
- `library()` calls inside `observeEvent()` / `eventReactive()` handlers;
- `BSgenome.*`, `EnsDb.*`, `org.*.eg.db`, `TxDb.*` or a large `data/` / `db/` directory;
- dependencies only on GitHub (`remotes::install_github`, a `DESCRIPTION` `Remotes:`);
- a `config.*` file containing an absolute path from the author's machine;
- no `LICENSE` file at all.

## 1. Dependency census, before the first build

Scan **every** `.R` / `.Rmd` file in the app directory, not just `global.R`/`app.R`:

```r
files <- list.files(".", pattern = "[.](R|r|Rmd)$", recursive = TRUE)
txt <- paste(unlist(lapply(files, readLines, warn = FALSE)), collapse = "\n")
libs <- unique(gsub("[()\"']", "", regmatches(txt, gregexpr("(library|require)\\([A-Za-z0-9._]+", txt))[[1]]))
libs <- sub("^(library|require)\\(", "", libs)
ns   <- unique(sub("::.*$", "", regmatches(txt, gregexpr("[A-Za-z][A-Za-z0-9._]+::", txt))[[1]]))
sort(unique(c(libs, ns)))
```

Put the union in `EXTRA_PKGS`. A plugin module that only runs on a click will not be
covered by the seed packages harvested from `global.R`, and the smoke test will not
notice (see section 5).

Then split the list:

| Bucket | Action |
|---|---|
| base + recommended (`MASS`, `Matrix`, `survival`, `mgcv`, `nlme`, `cluster`, ...) | drop from `EXTRA_PKGS`; they ship with R and a source install can fail |
| on CRAN / Bioconductor | leave to the resolver |
| archived CRAN / GitHub-only | `ARCHIVE_URLS` + `FORCED_PKGS` (section 4) |
| unavailable or unshippable | `SOFT_PKGS`, and record the disabled feature in `APP_NOTES` |

The workflow already treats base **and recommended** packages as always present, so a
recommended package in `EXTRA_PKGS` can no longer trigger a source rebuild on the runner.

## 2. Size budget

A GitHub Release asset is limited to 2 GiB, and a 1 GB zip already means a slow first
install for users. Compute the budget before building:

- app sources + demo data;
- `rlib/` per platform (the xOmicsShiny closure was ~600 MB);
- reference genomes: `BSgenome.Hsapiens.UCSC.hg38` is ~731 MB,
  `BSgenome.Mmusculus.UCSC.mm10` ~650 MB — a Seurat/ArchR stack plus both genomes cannot
  fit under 2 GiB.

Options, in order of preference:

1. **Drop demo data** (`EXCLUDE: "data"`) if every module can run without it.
2. **Make a heavy feature conditional** and patch the require at build time (section 3);
   document the missing module in `APP_NOTES` and in the upstream PR/issue.
3. Split into a "lite" and a "full" app id only as a last resort — two catalog entries to
   maintain, two bundles to rebuild.

Never ship a bundle that silently lacks a package the code calls: that is the failure
mode in section 5.

## 3. Build-time patches (`PATCH_SCRIPT`)

Set `PATCH_SCRIPT` to an R file in the upstream repo; it runs inside `bundle/app/` with
`rlib` on `.libPaths()` before zipping. Typical patches:

- **Absolute paths.** xOmicsShiny shipped `config.csv` with `server_dir` pointing at
  `D:/customProjects_NEW/...`. Rewrite it to `.`:

  ```r
  f <- "config.csv"
  if (file.exists(f)) {
    cfg <- utils::read.csv(f, stringsAsFactors = FALSE)
    i <- match("server_dir", cfg$category)
    if (!is.na(i)) cfg$value[i] <- "."
    utils::write.csv(cfg, f, row.names = FALSE)
  }
  ```

- **Optional module that cannot ship on macOS** (Mfuzz needs `tcltk`/XQuartz): guard the
  `library()`/`require()` so the module is disabled instead of crashing the app on start.

- **Heavy optional dependency** (BSgenome, Cairo): remove or conditionally guard the
  call, and say so in `APP_NOTES`.

Keep patches minimal and prefer guarding over deleting user-visible features; the patch
is a store-packaging change, not an app rewrite, and must be explained in the PR.

## 4. GitHub-only and archived packages

`ARCHIVE_URLS` takes source tarballs (CRAN archive or a GitHub release/tarball). The
workflow downloads each one, installs it into `rlib/`, and then **fails the build** if a
package listed in `FORCED_PKGS` is still absent. This check exists because a `try()`
around the install once swallowed a missing PCSF: the bundle built, the smoke test passed,
and the module died only when a user clicked it.

```yaml
ARCHIVE_URLS: "https://github.com/.../PCSF_1.24.0.tar.gz"
FORCED_PKGS: "PCSF topGO"
```

Add the package's own Bioconductor dependencies (PCSF needs `topGO`) either to
`EXTRA_PKGS` or to the tarball list. Check the resolved package list in `deps-<platform>.json`
after the build.

## 5. The smoke test loads the UI, not every module

`shinyAppDir()` builds the UI object; it does not evaluate click handlers. `library(PCSF)`
inside `observeEvent()` was therefore invisible to a green smoke test. Two defenses:

1. The workflow now checks that every `library()`/`require()`/`pkg::` name found in the
   app sources exists in `rlib/` (or is base/recommended, or listed in `SOFT_PKGS`), and
   fails the build otherwise. It strips R comments first, but a package name inside a
   string literal can still be a false positive.
2. For each plugin module, write down the click path you tested in the real ShinyApps
   shell. A CI bundle is not a tested install: open the app, run every advertised module,
   and only then bump the version for release.

If a module needs network (biomaRt, enrichR, pathview/KEGG), test it online and list the
offline limitation in `APP_NOTES`.

## 6. Time and failure handling

- Heavy closures take 20-50 minutes per platform. Set `SMOKE_TIMEOUT_SEC: "900"` for
  first-load-heavy apps; the build job itself has no timeout override.
- When a build is fixed, **bump the version** and publish a new tag (`v3.0.2` after a
  broken `v3.0.1`). Do not overwrite the bad release; delete the tag/release only after
  the replacement is verified.
- macOS portability failures have their own guide: `references/macos-portability.md`.

## Case notes

| App | Shape | What mattered |
|---|---|---|
| xOmicsShiny | flat, 24 modules | 76 packages scanned from all modules; `config.csv` absolute path; `metabaser` not on CRAN -> `SOFT_PKGS`; Cairo/gdtools/ggrastr and Mfuzz/tcltk blocked macOS -> rebuild/drop; PCSF archived + `topGO`; final zips 942/913 MB |
| ScRDAVis | flat, Seurat/monocle3/CellChat | 10 GitHub-only packages; two BSgenome references -> over 2 GiB with the full stack; dropped BSgenome and the TF-motif module, documented in `APP_NOTES`; no upstream LICENSE -> ask the author before listing |

## Checklist

- [ ] dependency union includes every module file
- [ ] recommended packages not listed as extras
- [ ] `ARCHIVE_URLS` + `FORCED_PKGS` cover every GitHub-only package
- [ ] no absolute author paths left in config/data files
- [ ] zip size and demo data checked against the 2 GiB limit
- [ ] every disabled feature is in `APP_NOTES` and the PR/issue
- [ ] version bumped, both platforms green, real shell tested per module
