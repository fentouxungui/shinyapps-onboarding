# First-launch and on-demand downloads

The default rule is simple: **a bundle must start offline**. A download at startup makes
the app fail on a plane, behind a proxy, or on a slow link, and the store cannot verify
what the user ends up with. Generate startup data at build time (`references/startup-data.md`).

There is one narrow exception: a **module the user explicitly opens** may fetch its own
large data on first use, if all of the conditions below hold. This came from ScRDAVis,
where two `BSgenome` references (731 MB + 650 MB) cannot fit in a GitHub Release next to a
484-package dependency closure.

## Conditions for a module-level download

1. **Never at startup.** No `require()`, `library()` or `install.packages()` for the heavy
   data in `global.R`/`app.R`. Trigger only from the module's own action button.
2. **Per artifact, not everything.** Download one genome/species/database the user actually
   selected. ScRDAVis downloads hg38 for human or mm10 for mouse, ~700 MB each, not 1.4 GB.
3. **User-writable library, not `rlib/`.** Install into `%APPDATA%\<App>\rlib`
   (macOS: `~/Library/Application Support/<App>/rlib`), add it with
   `.libPaths(c(user_lib, .libPaths()))`. The bundle directory may be read-only, is
   replaced on update, and is hash-checked by the store.
4. **Visible, cancellable, generous timeout.** Show a notification/progress with the size
   and expected time, set `options(timeout = 7200)`, and never block the UI thread.
5. **Readable failure.** On error, print the package, the URL, and the manual command
   (e.g. `BiocManager::install("BSgenome.Hsapiens.UCSC.hg38")`). Do not fail silently.
6. **Cached afterwards.** Second use must not re-download; check `requireNamespace()` first.
7. **Disclosed.** Write the module name, size, and offline limitation into `APP_NOTES`, the
   catalog entry notes, and the upstream PR/issue. The store does not verify user data.

## How the ShinyApps shell installs a bundle

Observed on shell 0.1.11: after install, the app's `rlib/` is not simply deleted. Package
directories are moved into a **global shared library** (`%APPDATA%\shinyapps\lib` --
600+ packages on a real machine), and the version directory keeps the original bundle at
`<app>/<version>/app/bundle/{app,rlib}` for repair/reinstall.

Consequences for downloaded data and vendored libraries:

- A per-user library **outside** the app version directory (`%APPDATA%\<App>\rlib`)
  survives upgrades, reinstall and rlib cleanup.
- Vendored dylibs inside `rlib/<pkg>/libs/` move with the package; `@loader_path`
  references keep resolving in the shared library.
- **Append** the user library -- `.libPaths(c(.libPaths(), user_lib))` -- instead of
  prepending it, so a user-installed package cannot shadow the shared library's version in
  the same session. Check `requireNamespace()` first and reuse a shared copy when present.
- Shared-library dedup is by package name+version. Two apps bundling the same package
  version with different vendored libraries can overwrite each other; this is rare, but if
  it matters keep a private copy under the app directory and add it only for that module.

## Reference shape

```r
user_lib <- file.path(Sys.getenv(if (.Platform$OS.type == "windows") "APPDATA" else "HOME"),
                      "ScRDAVis", "rlib")
dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
# Append: the shared library must win for packages it already provides.
.libPaths(c(.libPaths(), user_lib))

ensure_bsgenome <- function(pkg) {
  if (requireNamespace(pkg, quietly = TRUE)) return(invisible(TRUE))  # shared lib or user lib
  if (!requireNamespace("BiocManager", quietly = TRUE))
    stop("BiocManager is missing from the bundle; cannot fetch ", pkg)
  message("Downloading ", pkg, " (~700 MB); this runs once.")
  ok <- tryCatch({
    old <- options(timeout = 7200); on.exit(options(old), add = TRUE)
    BiocManager::install(pkg, lib = user_lib, update = FALSE, ask = FALSE)
    TRUE
  }, error = function(e) { message("Download failed: ", conditionMessage(e)); FALSE })
  if (!ok || !requireNamespace(pkg, quietly = TRUE))
    stop(pkg, " is not installed. Run: BiocManager::install(\"", pkg, "\")")
  invisible(TRUE)
}
```

Call it only from the module's handler (after the user picks a species), then `library()`
the package locally. Guard the module so the rest of the app still works when the user
declines the download or is offline.

## What to tell the author

- which modules need network and how large the download is;
- that the data lives in the user profile, outside the signed bundle;
- that macOS/Windows behaviour differs if the data source differs;
- that a first-use download is a deliberate exception, not the default packaging model.

## When not to do this

- The download is needed to render the landing page: then it is startup data, generate it
  at build time or drop the feature.
- The data is small (< ~50 MB): bundle it.
- The dependency cannot be installed as a binary (compiles for 20+ minutes on the user's
  machine): ship a prebuilt artifact or drop the module.
