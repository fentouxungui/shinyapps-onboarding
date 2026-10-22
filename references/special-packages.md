# App-specific package versions (Cairo and friends)

The ShinyApps shell does not keep each app's `rlib/` isolated. After install it moves
package directories into a **global shared library**, deduplicated by package name+version.
That is fine for ordinary CRAN packages, but not for packages whose files differ between
apps.

The canonical case is **Cairo**: when an app needs the macOS X11 client libraries, we copy
a subset of dylibs into `rlib/Cairo/libs/` and rewrite them to `@loader_path`
(`references/macos-portability.md`). A plain CRAN Cairo has no such files. If both apps
carry the same `Cairo` version, the shared library keeps one directory and one app loses
(or gains) the vendored libraries.

## Rule

**Every app that bundles a specially patched package must append a unique numeric suffix
to that package's version at build time.** Do not reuse a suffix across apps -- not even
"just this once" for an older app. Patching only the new app is not sufficient if an older
app already used the same suffix; the collision is between any two identical versions.

Use the template knobs:

```yaml
PKG_VERSION_PACKAGES: "Cairo"
PKG_VERSION_SUFFIX: "9003"      # numeric only
```

The assemble step rewrites `Version` in the installed package's `DESCRIPTION` before the
manifest, dependency lock and zip are produced, so `Cairo` becomes e.g. `1.7-0.9003`.
The suffix is part of a valid R version, so `packageVersion("Cairo")` and dependency
checks keep working.

Driver flags:

```powershell
.\scripts\onboard-shiny-app.ps1 ... -PkgVersionPackages Cairo -PkgVersionSuffix 9003
```

## Allocate before you build

```powershell
.\scripts\next-pkg-version.ps1 -Package Cairo -List
.\scripts\next-pkg-version.ps1 -Package Cairo -AppId myapp -Reserve
```

The registry is `apps/pkg-versions.tsv` (package, app, suffix, status, note). Reservation
returns the next free suffix and records the app; the build then uses that exact suffix.
CI (`validate-apps.ps1`) checks that:

- a package suffix is not registered twice;
- an app does not reserve the same package twice;
- a workflow that sets `PKG_VERSION_PACKAGES` has a matching registry row and suffix.

## Which packages need this

Any package whose contents you modify per app:

- packages with **vendored dylibs** (`Cairo`, occasionally `gdtools` or `ragg`);
- packages rebuilt with app-specific flags whose binaries end up in `libs/`;
- packages pinned to an app-specific commit.

Do **not** patch ordinary packages: unique versions fragment the shared library and force
duplicate installs for no reason.

## Existing releases

Suffixes apply at build time; a released bundle cannot be edited. Current state:

- **ScRDAVis v1.1.2** shipped Cairo without a suffix (Windows + macOS). Suffix `9001` is
  reserved for its next rebuild; until then, any new app that vendors Cairo must use a
  different suffix (e.g. `9002`), and coexistence with v1.1.2 is not guaranteed.
- New apps start at `9001` if no Cairo row exists; check the registry first.

## Verify

- Build log: `app-specific version: Cairo -> 1.7-0.9003`.
- `deps-<platform>.json` and `manifest.json` list the suffixed version.
- In the installed app, `packageVersion("Cairo")` returns the suffixed version.
- Two apps that both vendor Cairo must show two different suffixed versions in the shell
  diagnostics / shared library listing.
