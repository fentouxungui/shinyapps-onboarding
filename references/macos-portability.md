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

## R.framework absolute paths (base/recommended packages)

A different, more severe error:

```
Library not loaded: /Library/Frameworks/R.framework/Versions/4.6/Resources/lib/libRblas.dylib
Referenced from: .../lib/KernSmooth/libs/KernSmooth.so
```

This is **not** Homebrew/XQuartz. A base or recommended package (here `KernSmooth`)
was shipped in `rlib` (and then copied to the shell's shared library). It was linked
against the runner's R.framework, but the ShinyApps shell uses a portable R at a
different path, so the absolute install name cannot resolve.

Rules:

- `rlib/` must contain only app-level packages; **base + recommended** come from the
  bundled R.
- The template asserts this after installation and fails the build if any
  base/recommended package is present.
- The macOS audit now also flags `/Library/Frameworks/R.framework`; an app-level
  compiled package with that reference must be rebuilt/repatched or dropped.

## What the template already does

0. Downloads the **shell's portable R** (the matching `portable-r` release for the
   matrix platform/arch) and installs the app closure with its `Rscript`, so
   compiled packages link against the same runtime ShinyApps ships. `setup-r` is
   used only for build tooling. Installing with the CI framework R produces
   `/Library/Frameworks/R.framework` references and fails on users' Macs.
1. Installs dependencies (binary first, source fallback).
2. Excludes **base + recommended** packages from `rlib` and asserts that none slipped in.
3. On Darwin, applies `SOURCE_REBUILD: "<pkg> <pkg>"` **before** the audit: the packages are
   rebuilt from source with Homebrew removed from `PATH`/`PKG_CONFIG_PATH`, so they link
   against the runner's static libraries.
4. Audits every `.so`/`.dylib` in `rlib/` for `/opt/X11`, `/opt/homebrew`,
   `/usr/local/opt`, and `/Library/Frameworks/R.framework`, and fails the build if any
   remain.
5. Re-signs every Mach-O file in `bundle/` with `codesign --force --sign -` and
   verifies each signature before zipping (see "Re-sign after `.portable` patching" below).
6. Runs the smoke test on the mac runner.

The audit regex is deliberately unanchored: `otool -L` output is tab-indented, and an
anchored `^/opt/...` pattern silently passes everything. If you edit that block, test it
against a package you know is broken.

## The portable R `.portable` environment and `R_PROFILE`

`portable-r-macos` ships an `etc/Rprofile.site` that attaches a hidden `.portable`
environment and wraps `install.packages()`; after each install it rewrites CRAN
binary `.so` files from absolute `/Library/Frameworks/R.framework/...` paths to
`@rpath/...`. If the audit reports many unrelated binary packages at once
(`Biobase.so`, `DESeq2.so`, `RcppArmadillo.so`, ...), the patcher did not run.

The usual cause is an **empty** `R_PROFILE`. R treats an empty value as set, so
the default `$R_HOME/etc/Rprofile.site` is skipped and `.portable` never attaches.
Set `R_PROFILE` explicitly to `$PORTABLE_R_HOME/etc/Rprofile.site`. The site
profile also resets `.libPaths()` to the portable R library, so point
`R_PROFILE_USER` at a small profile that adds the harness library back. The
template's `Set up portable R` step does both and fails early if `.portable` is
not on the search path.

Do not use `Rscript --vanilla`: it skips the site profile for the same reason.

## Re-sign after `.portable` patching

`portable-r-macos` signs its own Mach-O binaries, but the `.portable` wrapper's
`fix_pkgs()` runs `install_name_tool` on CRAN binary `.so` files **after**
`install.packages()` and does not re-sign them. Rewriting load commands invalidates the
embedded code signature. On a user Mac, loading such a package can kill the R process:

```
Exception Type: EXC_BAD_ACCESS (SIGKILL (Code Signature Invalid))
Termination Reason: Namespace CODESIGNING, Code 2 Invalid Page
```

The build can look green because the smoke test runs before the package is exercised, and
`codesign --verify` on the `.app` can pass: the bad file may be in the shell's shared
library (`~/Library/Application Support/<slug>/lib`), outside the app bundle. A real case
was `data.table/libs/data_table.so`; `library(shiny)` loaded it and R was killed.

The template's **Re-sign macOS binaries after portable-R patching** step walks every file
in `bundle/`, ad-hoc signs each Mach-O file, and fails the build if `codesign --verify`
rejects one. Keep it after any `PATCH_SCRIPT`/`PREFETCH_SCRIPT` that can modify the bundle,
and before the zip step. For an already-installed app, the user-side equivalent is:

```bash
find "$HOME/Library/Application Support/<slug>/lib" -type f \
  \( -name '*.so' -o -name '*.dylib' \) -print0 |
while IFS= read -r -d '' f; do
  file -b "$f" | grep -q 'Mach-O' || continue
  xattr -cr "$f" 2>/dev/null || true
  codesign --force --sign - "$f"
  codesign --verify --verbose=1 "$f"
done
```

Do not re-sign the portable R runtime itself with `-` in this step; it already has its
Developer ID signature. Sign the package library (`rlib/` / `runtime/R/library`) after all
installs.

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
4. **Declare it unshippable on macOS.** Publish Windows-only, delete the macOS matrix
   entry, and record the reason in `APP_NOTES` and the PR.

The runner label is separate from the app's macOS compatibility floor. `macos-14`
was retired on 2026-11-02; use `macos-15` (arm64) for the bundle build. Keep the
minimum supported macOS in documentation, not in `runs-on:`.

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
- **Trusting a green macOS smoke as "works on Mac".** A server + `/` smoke does not touch
  every module; test the real ShinyApps shell.

## Verify before publishing

- The audit step prints no offenders (not just "no error").
- Every Mach-O file in `bundle/` passes `codesign --verify` after the re-signing step.
- `deps-mac-arm64.json` contains the packages you expect, including any `FORCED_PKGS`.
- The mac smoke test passes with only `rlib` + base R.
- If a feature was disabled, it is in `APP_NOTES` and in the upstream PR/issue.

## Shared-library dedup

The ShinyApps shell moves package directories into a global library after install. Bundled
dylibs move with them, so `@loader_path` still resolves. But dedup is keyed by package
name+version: two apps that bundle the same package version with different vendored
libraries can overwrite each other.

The same dedup keeps a bad macOS signature alive: if an already-installed shared package
has an invalid signature, reinstalling an app that ships the same package version may reuse
the existing directory instead of replacing it. Re-sign the installed shared library (or
clear that package from the store's library) after fixing the build; a new bundle alone is
not guaranteed to replace an existing same-version copy.

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
