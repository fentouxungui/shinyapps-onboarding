# Icon sourcing

Store icons are 512x512 PNG at `ShinyApps/icons/<id>.png`. Use the project's **own**
logo, never a screenshot or a platform logo. Search in this order:

1. **Repository files** (one tree call, score by path):
   - `man/figures/logo.png` / `logo.svg` (best)
   - `man/figures/*logo*.png`
   - `inst/**/www|img|images/*logo*.png`
   - `inst/**/*logo*.png`
   - `www|images|img|assets/**/*logo*|*icon*.png`
   - `hex/`, `sticker/`, `*hex*.png`
   - skip `revdep/`, `docs/reference/`, `tests/`.
2. **README** (Markdown and HTML `<img>`): accept only when the URL or alt text contains
   `logo|hex|icon`; reject `shields|badge|codecov|travis|joss|cranlogs|r-pkg|status.svg`.
3. **pkgdown**: `_pkgdown.yml` `logo:` or `logo: image:`.
4. **Project site**: the repo's About `homepage` (GitHub API `homepage`) and links in the
   README matching `forge.|gitlab|r-universe|github.io|sourceforge|bioconductor`.
   Fetch the page and take `og:image`, a **project avatar**
   (`/uploads/-/system/project/avatar/...` on GitLab/Forge), or an `<img>` containing the
   project name/logo.
5. Only when none of the above exists: generate a letter tile.

## Reject

- Platform logos: Bioconductor generic logo, CRAN logo, RStudio/Posit, DemoTools or other
  dependency logos. They are not the app's identity.
- Posters, screenshots, banners, example figures, badges.
- Site favicons (`appearance/favicon`, `apple-touch-icon`, `/assets/`).

## Validate and protect

- Convert to 512x512 RGBA, contain-fit with transparent padding.
- Reject sources whose alpha coverage is < 2% after fit (near-empty images).
- **Never overwrite an existing icon blindly.** Diff the current file against the
  candidate; if the current icon is larger/meaningful and the new one is smaller or a
  generic image, keep the current one. Restore mistakes with
  `git checkout <good-commit> -- icons/<id>.png`.
- Apply all replacements in one commit: `icons: use real upstream logos ...`.

## Verify identity, not just presence

A logo file that exists is not necessarily the app's logo. Familia's repository ships both
`inst/app/www/familia_logo.png` (the app) and `inst/app/www/breedverse_logo.png` (the parent
program); the store icon was the Breedverse one. Prefer the file whose name matches the app,
then open the 512x512 render and confirm it carries the app's name/mark. Never ship a
parent-program, dependency, institution or platform logo. When a repository has several
candidate logos, compare the rendered results and record which file you chose in `NOTES.md`.