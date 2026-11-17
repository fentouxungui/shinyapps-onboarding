# Independent platform releases and Run Bundle

A matrix build job has **one aggregate result**. A release job with
`needs: bundle` and no `always()` is skipped when either platform fails, so a
successful mac bundle is never published if Windows fails. This is a common
failure on apps whose two platforms have different dependency/toolchain luck.

## Build Bundle: release only the platforms that built

Keep the matrix build; make the release job independent of the aggregate result:

```yaml
release:
  needs: [resolve, bundle]
  if: always() && needs.resolve.result == 'success' && needs.bundle.result != 'cancelled'
  runs-on: ubuntu-latest
  permissions:
    contents: write
  env:
    TAG: ${{ needs.resolve.outputs.tag }}
  steps:
    - uses: actions/download-artifact@v4
      continue-on-error: true
      with:
        path: artifacts
        merge-multiple: true
    - name: Check for built bundles
      id: check
      shell: bash
      run: |
        set -euo pipefail
        count=0
        if [ -d artifacts ]; then
          count=$(find artifacts -maxdepth 1 -type f -name '*.zip' | wc -l | tr -d ' ')
        fi
        echo "count=$count" >> "$GITHUB_OUTPUT"
        if [ "$count" -eq 0 ]; then
          echo "::warning::No successful platform artifacts; nothing to release."
        fi
    - name: Attach bundles to the tag's Release
      if: steps.check.outputs.count != '0'
      env:
        GH_TOKEN: ${{ github.token }}
        REPO: ${{ github.repository }}
        EVENT_NAME: ${{ github.event_name }}
        ALLOW_CREATE: ${{ inputs.allow_create_release }}
      shell: bash
      run: |
        set -euo pipefail
        # Release only the platform zips. The ShinyApps catalog derives sha256
        # from GitHub's asset digest and ignores non-zip assets.
        files=(artifacts/*.zip)
        # gh release view/create/upload; per-platform files only
```

Key rules:

* **Release only the platform zips.** ShinyApps `publish-catalog` matches
  `<id>-<version>-<platform>[-r<abi>].zip` and derives `sha256` from GitHub's
  asset digest; non-zip assets are ignored. Keep `meta-*`/`deps-*`/checksum
  files as Actions artifacts. Publishing per-run shared or per-platform meta
  files adds no store value and can collide when a second platform is added
  later.
* The release job must run with `always()` but only upload what exists. If both
  legs failed, `steps.check.outputs.count == 0` and the release step is skipped.
* The overall workflow is still red when one leg fails; that is correct. The
  successful platform is released, and a later Run Bundle can build the missing
  platform.
* A single release job avoids two release jobs racing to create the same
  Release. If you need truly separate per-platform release jobs, split the build
  into `build-win`/`build-mac` jobs (via a reusable workflow or composite action,
  not by duplicating 600 lines) and use
  `if: always() && needs.build-win.result == 'success'` for `release-win`. A
  matrix leg has no individual `needs.<job>.result`; the artifact check is the
  per-leg signal.
* Create the Release only for a tag push, or for a `workflow_call` with
  `allow_create_release: true` (Run Bundle uses this when the tag has no Release
  yet). A direct manual dispatch remains attach-only.

## Build Bundle: `platforms` input and plan job

Run Bundle needs to build only the missing platform. Add reusable/callable inputs
and a plan job that outputs a matrix:

```yaml
on:
  push:
    tags: ['v*']
  workflow_dispatch:
    inputs:
      tag: { required: true, type: string }
      platforms:
        type: choice
        options: [all, win-x64, mac-arm64]
        default: all
  workflow_call:
    inputs:
      tag: { required: true, type: string }
      platforms: { required: false, default: all, type: string }
      allow_create_release: { required: false, default: false, type: boolean }

jobs:
  resolve: ...
  plan:
    needs: resolve
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.matrix.outputs.matrix }}
    steps:
      - id: matrix
        shell: bash
        env:
          PLATFORMS: ${{ inputs.platforms || 'all' }}
        run: |
          set -euo pipefail
          case "$PLATFORMS" in
            all) matrix='{"include":[{"os":"windows-latest","platform":"win-x64"},{"os":"macos-15","platform":"mac-arm64"}]}' ;;
            win-x64) matrix='{"include":[{"os":"windows-latest","platform":"win-x64"}]}' ;;
            mac-arm64) matrix='{"include":[{"os":"macos-15","platform":"mac-arm64"}]}' ;;
            *) echo "::error::unknown platforms: $PLATFORMS"; exit 1 ;;
          esac
          echo "matrix=$matrix" >> "$GITHUB_OUTPUT"
  bundle:
    needs: [resolve, plan]
    strategy:
      fail-fast: false
      matrix: ${{ fromJSON(needs.plan.outputs.matrix) }}
```

The resolve job must use `inputs.tag` (workflow_call and workflow_dispatch) with
`github.ref_name` as the push fallback. The release job's create condition should
allow `push` or `allow_create_release == 'true'`.

## Run Bundle: check the Release before building

A separate Run Bundle workflow inspects the tag's published Release, builds only
missing platforms, and passes the subset to Build via `workflow_call`:

```yaml
name: Run bundle
on:
  workflow_dispatch:
    inputs:
      tag: { required: true, type: string }
permissions:
  contents: write

jobs:
  check:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.check.outputs.tag }}
      platforms: ${{ steps.check.outputs.platforms }}
      release_exists: ${{ steps.check.outputs.release_exists }}
    steps:
      - id: check
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
          INPUT_TAG: ${{ inputs.tag }}
        run: |
          set -euo pipefail
          raw="${INPUT_TAG#refs/tags/}"; raw="${raw#v}"
          raw="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
          [ -n "$raw" ] || { echo "::error::tag is required"; exit 1; }
          tag="v$raw"; version="$raw"; app=scrnatoolvis; r_abi=4.6
          echo "tag=$tag" >> "$GITHUB_OUTPUT"
          git ls-remote --tags "https://github.com/${GITHUB_REPOSITORY}.git" "refs/tags/$tag" | grep -q . \
            || { echo "::error::tag $tag not found"; exit 1; }

          ERR="$(mktemp)"; set +e
          release_json="$(gh release view "$tag" --repo "$GITHUB_REPOSITORY" \
            --json assets,isDraft,isPrerelease 2>"$ERR")"; rc=$?
          set -e
          exists=false; win=false; mac=false
          if [ "$rc" -eq 0 ]; then
            [ "$(jq -r .isDraft <<<"$release_json")" = true ] && { echo "::error::draft Release"; exit 1; }
            [ "$(jq -r .isPrerelease <<<"$release_json")" = true ] && { echo "::error::prerelease"; exit 1; }
            exists=true
            while IFS= read -r n; do
              case "$n" in
                "$app-$version-win-x64-r$r_abi.zip"|"$app-$version-win-x64.zip") win=true ;;
                "$app-$version-mac-arm64-r$r_abi.zip"|"$app-$version-mac-arm64.zip") mac=true ;;
              esac
            done <<< "$(jq -r '.assets[]?.name' <<<"$release_json")"
          elif ! grep -qiE 'release not found|HTTP 404' "$ERR"; then
            cat "$ERR"; exit 1
          fi
          need_win=$([ "$win" = true ] && echo false || echo true)
          need_mac=$([ "$mac" = true ] && echo false || echo true)
          platforms=""
          if [ "$need_win" = true ] && [ "$need_mac" = true ]; then platforms=all
          elif [ "$need_win" = true ]; then platforms=win-x64
          elif [ "$need_mac" = true ]; then platforms=mac-arm64
          fi
          echo "release_exists=$exists" >> "$GITHUB_OUTPUT"
          echo "platforms=$platforms" >> "$GITHUB_OUTPUT"
          echo "win=$win mac=$mac -> build='$platforms'"

  build:
    needs: check
    if: needs.check.outputs.platforms != ''
    permissions:
      contents: write
    uses: ./.github/workflows/build-app-bundle.yml
    with:
      tag: ${{ needs.check.outputs.tag }}
      platforms: ${{ needs.check.outputs.platforms }}
      allow_create_release: ${{ needs.check.outputs.release_exists != 'true' }}
```

## Outcomes and edge cases

| State | `platforms` | Behaviour |
|---|---|---|
| both assets present | `""` | Build job skipped; run green |
| both missing | `all` | Build both; create the Release if absent |
| only win present | `mac-arm64` | Build mac; attach to existing Release |
| only mac present | `win-x64` | Build win; attach to existing Release |
| Release exists, asset missing | missing platform | Attach; do not create a second Release |
| no Release, tag exists | all/missing | `allow_create_release=true`; Build creates it |
| draft/prerelease Release | check fails | Publish/delete it; it is not a catalog-visible success |
| asset for another R ABI | treated missing | Build current `r<abi>`; do not skip |
| legacy unsuffixed asset | present | Accepted by the catalog |
| both builds fail | none | Release step skips; workflow red; retry Run Bundle |
| one build fails | one | Successful platform released; rerun builds the other |
| immutable asset exists | duplicate | Release job fails; use a new tag/version, no clobber |

Additional notes:

* `needs.bundle.result` is aggregate. `always()` + artifact presence is the
  minimal fix; split build jobs only if you need per-job `needs.<job>.result`.
* Public repo `git ls-remote` works unauthenticated; private repos need a PAT or
  a `gh api` tag check with the token.
* The Run Bundle check uses the current `APP_ID`, version and R ABI. Keep them
  aligned with the Build workflow's `env:`.
* `workflow_call` caller jobs need `permissions: contents: write`; the called
  workflow's release job also declares it. A reusable workflow cannot elevate the
  caller's token.
* Do not publish `SHA256SUMS`/`build-info.json` or per-platform `meta-*` files
  as Release assets for independent runs. Keep them as Actions artifacts.
  ShinyApps ignores non-zip release assets and records `sha256` from GitHub's
  asset digest, so the zips alone are the complete store contract.
