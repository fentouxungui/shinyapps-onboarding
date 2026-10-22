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

Work down this list; stop at the first option that passes the audit, the smoke test and a
real shell test.

1. **Source rebuild.** `SOURCE_REBUILD: "gdtools"` (or `Cairo`, `ragg`, `systemfonts`,
   `textshaping`). This is the normal fix for an OpenMP/cairo binary from CRAN.
2. **Vendor the dylibs (works for XQuartz).** Copy the referenced libraries into the
   package's `libs/` directory, rewrite the install names to `@loader_path/...`, ad-hoc
   `codesign` them, and recurse. This is how ScRDAVis v1.1.2 ships `Cairo` on macOS with no
   XQuartz on the user's machine. See the recipe below.
3. **Drop or guard the feature.** `Mfuzz` needs `tcltk` (the Tcl/Tk framework, not just the
   X11 client libraries) -- guard its `library()` so the module is disabled on macOS only.
4. **Declare it unshippable on macOS.** Publish Windows-only, delete the `macos-14` matrix
   entry, and record the reason in `APP_NOTES` and the PR.

## Vendoring XQuartz dylibs (ScRDAVis recipe)

`Cairo.so` needs libXrender/libX11/libxcb at **load time**, but `ggrastr`/Cairo draw to an
image surface, so no X server is involved. The X11 client libraries are ordinary dylibs
and their licence allows redistribution; total cost is ~15-30 MB per bundle.

1. Install XQuartz on the **runner only** (e.g. the 2.8.6 pkg, or `brew install --cask xquartz`).
   This is a build-time dependency; users do not install it.
2. For every `.so`/`.dylib` whose `otool -L` output contains `/opt/X11` (or Homebrew):
   - copy each referenced library into that package's `libs/` directory;
   - `install_name_tool -change <old> @loader_path/<name> <binary>` for the package binary;
   - also rewrite the copied libraries' own references (libxcb -> libXau/libXdmcp, ...),
     iterating until no absolute paths remain;
   - `codesign --force --sign - <file>` after each rewrite (arm64 refuses unsigned edits).
3. Re-run the audit; any remaining absolute reference is a hard failure that names the file.
4. Smoke test on the runner, then install the bundle on a clean Mac (no XQuartz, no
   Homebrew) before publishing.

`gdtools` still needs the source rebuild: it links XRender but is easy to rebuild
statically, which is cheaper than vendoring. Keep `SOURCE_REBUILD: "gdtools"` next to the
X11 vendoring.

## Build-time system dependencies (openssl, hdf5)

Bioconductor source packages (ScRDAVis: `alabaster.base`, `BPCells`) need system headers
that CRAN binaries do not: Homebrew's `openssl@3` is keg-only, and `BPCells` needs HDF5.
Set `MACOS_BREW_DEPS: "openssl@3 hdf5"`; the template installs them, exports
`PKG_CONFIG_PATH`/`CPPFLAGS`/`LDFLAGS`, and also writes them into `~/.R/Makevars` because
`R CMD INSTALL` does not reliably inherit `LDFLAGS` for source packages.

Two pitfalls seen in practice:

- **Do not blank `PKG_CONFIG_PATH` without restoring it.** `SOURCE_REBUILD` hides Homebrew
  by clearing `PATH`, `PKG_CONFIG_PATH` and `PKG_CONFIG_LIBDIR`; if only `PATH` is restored,
  every later `configure` (BPCells -> hdf5) fails. The template restores all three.
- The vendoring loop must run **after** these packages are installed, so it sees the new
  `/opt/homebrew/opt/openssl@3` and `/opt/homebrew/opt/hdf5` links.

## What not to do

- **`dylibbundler` in a loop.** On xOmicsShiny it copied dependencies recursively and hung
  the job for ~50 minutes. Prefer a bounded `install_name_tool` pass.
- **Copying the first fix over the whole install block.** Rewriting the portability block
  once deleted the `ARCHIVE_URLS` and fix-up loops; the build stayed green while a package
  was never installed. Re-read the whole `Assemble bundle` step after any edit.
- **Trusting a green macOS smoke as "works on Mac".** `shinyAppDir()` does not touch every
  module; test the real ShinyApps shell.

## Verify before publishing

- The audit step prints no offenders (not just "no error").
- `deps-mac-arm64.json` contains the packages you expect, including any `FORCED_PKGS`.
- The mac smoke test passes with only `rlib` + base R.
- If a feature was disabled, it is in `APP_NOTES` and in the upstream PR/issue.

## Shared-library dedup

The ShinyApps shell moves package directories into a global library after install. Bundled
dylibs move with them, so `@loader_path` still resolves. But dedup is keyed by package
name+version: two apps that bundle the same package version with different vendored
libraries can overwrite each other.

Therefore **every app that vendors libraries into a package must give that package a unique
version suffix** (`PKG_VERSION_PACKAGES` / `PKG_VERSION_SUFFIX`). Do not patch only the new
app: every app that ships the package must use a different suffix. Allocate it with
`scripts/next-pkg-version.ps1 -Package Cairo` and follow
`references/special-packages.md`. A released bundle (e.g. ScRDAVis v1.1.2) cannot be
retro-patched; it must be rebuilt to comply.

## Fonts and Cairo

A rebuilt or vendored `Cairo`/`systemfonts` may still need font configuration at runtime.
If the user reports fontconfig/font errors on first launch, ship a minimal `fonts.conf`
inside the app and point `FONTCONFIG_FILE` at it from the app's `global.R` -- then re-test
on a clean Mac, not on the build runner.
