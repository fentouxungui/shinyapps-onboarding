# macOS bundle portability (XQuartz, Homebrew and dylibs)

The macOS job is the one that fails late. CRAN's macOS binaries are built on a machine
with Homebrew and XQuartz, and a few of them keep absolute references to those paths.
On a user Mac without them the package fails to load, so the workflow treats a
non-portable `.so`/`.dylib` as a build failure instead of shipping a broken bundle.

Typical error:

```
Error: non-portable dylib references: Cairo.so, gdtools.so
```

`otool -L` on those files shows `/opt/homebrew/opt/cairo/...` or `/opt/X11/lib/libXrender...`.

## What the template already does

1. Installs dependencies (binary first, source fallback).
2. On Darwin, applies `SOURCE_REBUILD: "<pkg> <pkg>"` **before** the audit: the packages are
   rebuilt from source with Homebrew removed from `PATH`/`PKG_CONFIG_PATH`, so they link
   against the runner's static libraries.
3. Audits every `.so`/`.dylib` in `rlib/` for `/opt/X11`, `/opt/homebrew`, `/usr/local/opt`
   and fails the build if any remain.
4. Runs the smoke test on the mac runner.

The audit regex is deliberately unanchored: `otool -L` output is tab-indented, and an
anchored `^/opt/...` pattern silently passes everything. If you edit that block, test it
against a package you know is broken.

## Remediation ladder

Work down this list; stop at the first step that passes the audit and the smoke test.

1. **Source rebuild.** `SOURCE_REBUILD: "gdtools"` (or `Cairo`, `ragg`, `systemfonts`,
   `textshaping`). This is the normal fix for an OpenMP/cairo binary from CRAN.
2. **Drop the feature that pulls the package.** `Cairo` arrives through `ggrastr`; making
   "Rasterize plot" draw vector output removes the dependency without touching the rest
   of the app. `Mfuzz` needs `tcltk` (XQuartz) — guard its `library()` so the module is
   disabled on macOS only.
3. **Vendor the dylibs.** Copy the needed libraries into the package directory and rewrite
   the install names with `install_name_tool -change ... @loader_path/...`, then
   `codesign --force --sign -` each rewritten binary. Bound the loop (one pass over a
   fixed dependency list), print each file, and re-run the audit.
4. **Declare it unshippable on macOS.** If the package needs a running X server (`tcltk`,
   `summarytools`, some `Cairo` builds), mark the app Windows-only or drop the feature.
   Do not publish a mac asset "to be symmetric".

## What not to do

- **`dylibbundler` in a loop.** On xOmicsShiny it copied dependencies recursively and hung
  the job for ~50 minutes until it was cancelled. Prefer a bounded `install_name_tool`
  pass, or the source rebuild.
- **Copying the first fix over the whole install block.** Rewriting the portability block
  once deleted the `ARCHIVE_URLS` and fix-up loops; the build stayed green while a package
  was never installed. Re-read the whole `Assemble bundle` step after any edit and diff it.
- **Trusting a green macOS smoke as "works on Mac".** `shinyAppDir()` does not touch every
  module; test the real ShinyApps shell.

## Verify before publishing

- The audit step prints no offenders (not just "no error").
- `deps-mac-arm64.json` contains the packages you expect, including any `FORCED_PKGS`.
- The mac smoke test passes with only `rlib` + base R.
- If a feature was disabled, it is in `APP_NOTES` and in the upstream PR/issue.

## Fonts and Cairo

A rebuilt `Cairo`/`systemfonts` may still need font configuration at runtime. If the user
reports fontconfig/font errors on first launch, ship a minimal `fonts.conf` inside the app
and point `FONTCONFIG_FILE` at it from the app's `global.R` — then re-test on a clean Mac,
not on the build runner.
