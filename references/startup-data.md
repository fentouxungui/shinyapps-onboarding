# Prefetching first-launch data into the bundle

Some Shiny apps download a database on first launch and cache it in their working directory.
That fails in the desktop bundle: the user may be offline, and R's default `download.file`
timeout is 60 s, so a large dump aborts mid-stream (`Timeout of 60 seconds was reached`,
`downloaded length X != reported length Y`) and the app errors at startup. Do not patch the app;
generate the data at build time and ship it in the bundle, so the app's own "file exists?" guard is
satisfied and it never downloads.

## Detect it

- Read `server.R` / `global.R` / `app.R` for `download.file` (including wrappers such as
  `processNcbiTaxonomy()`), `AnnotationHub`, `taxizedb`, `KEGG`, or a URL fetched inside a top-level
  `observe()` / `observeEvent()` / reactive that runs on start.
- Look for an idempotence guard just before it: `if (!file.exists("data/<db>")) { ... download ... }`.
  That guard is exactly what the shipped bundle must satisfy.
- The `Smoke test` step loads the app but never opens a session, so it will **not** catch this. The
  failure only appears when the app actually starts.

## Fix (default): the `PREFETCH_SCRIPT` hook

1. Add an idempotent R script to the fork (e.g. `scripts/prefetch-<id>.R`) that writes the data into
   the current working directory (the bundled `app/`), using the same call the app makes:

   ```r
   # scripts/prefetch-phyloprofile.R
   library(PhyloProfile)
   dir.create("data", showWarnings = FALSE)
   target <- "data/preProcessedTaxonomy.txt"
   if (!file.exists(target))
     write.table(processNcbiTaxonomy(), target,
                 col.names = TRUE, row.names = FALSE, quote = FALSE, sep = "\t")
   ```

2. Set `PREFETCH_SCRIPT` in the workflow env to that repo-relative path. The template runs it after
   the bundle is assembled and before zipping, with the bundled `rlib/` on `.libPaths()` and the
   working directory set to `bundle/app`, so everything it writes ships inside `app/`. It runs per
   platform, which is fine for cheap data.

## Fix (heavy dumps): a dedicated job

Parsing a full NCBI dump needs hundreds of MB of RAM. Running that per platform is wasteful and can
OOM the 7 GB macOS runner. Generate it once in its own job and pass it to the bundle jobs as an
artifact:

```yaml
jobs:
  taxonomy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
        with: { r-version: ${{ env.R_VERSION }}, use-public-rspm: true }
      - name: Build preProcessedTaxonomy.txt
        timeout-minutes: 45
        shell: Rscript {0}
        run: |
          options(timeout = 3600)
          source("R/createTaxonomyMatrix.R")   # defines processNcbiTaxonomy()
          dir.create("taxonomy", showWarnings = FALSE)
          write.table(processNcbiTaxonomy(), "taxonomy/preProcessedTaxonomy.txt",
                      col.names = TRUE, row.names = FALSE, quote = FALSE, sep = "\t")
      - uses: actions/upload-artifact@v4
        with: { name: taxonomy, path: taxonomy/preProcessedTaxonomy.txt }

  bundle:
    needs: taxonomy
    # ... existing bundle steps ...
    steps:
      # after the bundle is assembled, before zipping:
      - uses: actions/download-artifact@v4
        with: { name: taxonomy, path: taxonomy }
      - name: Add pre-generated taxonomy to the app bundle
        shell: bash
        run: |
          mkdir -p bundle/app/data
          cp taxonomy/preProcessedTaxonomy.txt bundle/app/data/preProcessedTaxonomy.txt
```

Set `options(timeout = 3600)` and retry a few times (the dump host is occasionally slow). Fail the
job if the file is missing rather than shipping a half-built app.

## Worked example: PhyloProfile

`inst/PhyloProfile/server.R` runs `processNcbiTaxonomy()` in an `observe()` guarded by
`file.exists("data/preProcessedTaxonomy.txt")`, which downloads and parses the ~76 MB NCBI
`taxdmp.zip` on first launch. The fork pre-generates that file in a `taxonomy` job (ubuntu, one
generation) and the bundle jobs copy it to `app/data/preProcessedTaxonomy.txt` before zipping. The
app then finds it and never downloads: the 0.1.1 bundles carry a ~148 MB
`app/data/preProcessedTaxonomy.txt` and start offline.

## Verify

- Unzip the produced `<id>-<version>-<platform>.zip` and confirm the file is inside `app/` with a
  plausible size (PowerShell `[IO.Compression.ZipFile]::OpenRead(...)`, or `unzip -l` on bash).
- The release asset should grow by roughly the compressed data size versus the previous version.
- Bump the version tag; a same-tag rebuild gives installed clients no `Update`.
