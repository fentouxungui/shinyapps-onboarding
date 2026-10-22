<#
  backfill-from-catalog.ps1 -- create apps/<id>/ records from ShinyApps/catalog/apps.yml.

  For each catalog entry it finds the newest release with '<id>-...-<platform>.zip' assets,
  snapshots the workflow **at that tag**, and writes meta.yml + NOTES.md. Existing records
  are skipped unless -Force. Intended for backfilling the pre-record apps; new releases
  should use record-app.ps1.

  Usage:
    .\scripts\backfill-from-catalog.ps1 -CatalogPath ..\ShinyApps\catalog\apps.yml -Limit 30 -Offset 0
    .\scripts\backfill-from-catalog.ps1 -CatalogPath ... -Ids "isee,spatiallibd"

  Requires a GitHub token (GITHUB_TOKEN) or a stored credential.
#>
param(
  [Parameter(Mandatory = $true)][string]$CatalogPath,
  [string]$AppsDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'apps'),
  [ValidateSet('active', 'pending', 'withdrawn', 'rejected', 'abandoned')][string]$Status = 'active',
  [string[]]$Ids = @(),
  [int]$Limit = 0,
  [int]$Offset = 0,
  [switch]$SkipExisting,
  [switch]$Force,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

$tok = $env:GITHUB_TOKEN
if (-not $tok) {
  $cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
  $tok = (($cred | Where-Object { $_ -like 'password=*' }) -replace '^password=','')
}
if (-not $tok) { throw 'No GitHub token: set GITHUB_TOKEN or store a credential for github.com' }
$H = @{ Authorization = "token $tok"; 'User-Agent' = 'shinyapps-onboarding'; Accept = 'application/vnd.github+json' }

function Api([string]$Uri) { Invoke-RestMethod -Uri $Uri -Headers $H -TimeoutSec 60 }
function TryApi([string]$Uri) { try { Api $Uri } catch { $null } }
function Get-LfSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes(($Text -replace "`r`n", "`n"))
  $h = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  (([BitConverter]::ToString($h)) -replace '-', '').ToLower()
}
function EnvValue([string]$Text, [string]$Key) {
  $m = [regex]::Match($Text, '(?m)^\s*' + [regex]::Escape($Key) + '\s*:\s*"([^"]*)"')
  if ($m.Success) { $m.Groups[1].Value } else { '' }
}

if (-not (Test-Path -LiteralPath $CatalogPath)) { throw "catalog not found: $CatalogPath" }
$entries = @()
$cur = $null
foreach ($line in Get-Content -LiteralPath $CatalogPath) {
  if ($line -match '^\s*-\s+id:\s*(.+?)\s*$') {
    if ($cur) { $entries += [pscustomobject]$cur }
    $cur = [ordered]@{ id = $Matches[1].Trim().Trim('"') }
    continue
  }
  if ($cur -and $line -match '^\s{4,}([A-Za-z_]+):\s*(.*?)\s*$') {
    $k = $Matches[1]; $v = $Matches[2].Trim().Trim('"')
    if (-not $cur.Contains($k)) { $cur[$k] = $v }
  }
}
if ($cur) { $entries += [pscustomobject]$cur }
if ($Ids.Count -gt 0) {
  $idSet = @()
  foreach ($x in $Ids) { $idSet += @(($x -split ',') | Where-Object { $_ }) }
  $entries = @($entries | Where-Object { $idSet -contains $_.id })
}
$entries = @($entries | Sort-Object id)
if ($Offset -gt 0) { $entries = @($entries | Select-Object -Skip $Offset) }
if ($Limit -gt 0) { $entries = @($entries | Select-Object -First $Limit) }
Write-Host "[backfill] $($entries.Count) catalog entrie(s)"

$ok = 0; $skipped = 0; $failed = 0
foreach ($e in $entries) {
  $id = $e.id
  $repo = $e.repo
  if (-not $repo) { Write-Host "[skip] $id : no repo" -ForegroundColor DarkYellow; $skipped++; continue }
  $dir = Join-Path $AppsDir $id
  if ((Test-Path -LiteralPath (Join-Path $dir 'meta.yml')) -and ($SkipExisting -or -not $Force)) {
    Write-Host "[skip] $id : record exists"
    $skipped++
    continue
  }

  try {
    $rels = @((Api "https://api.github.com/repos/$repo/releases?per_page=20") | ForEach-Object { $_ })
    $rel = $null
    foreach ($r in $rels) {
      if (@($r.assets | Where-Object { $_.name -match "^$([regex]::Escape($id))-.*-(win-x64|mac-arm64)\.zip$" }).Count -gt 0) { $rel = $r; break }
    }
    if (-not $rel) { throw "no release with $id-*.zip assets in $repo" }
    $tag = $rel.tag_name

    $commit = Api "https://api.github.com/repos/$repo/commits/$([uri]::EscapeDataString($tag))"

    $wfList = @((Api "https://api.github.com/repos/$repo/contents/.github/workflows?ref=$([uri]::EscapeDataString($tag))") | ForEach-Object { $_ })
    $candidates = @($wfList | Where-Object { $_.name -match '\.ya?ml$' })
    $preferred = @($candidates | Where-Object { $_.name -eq "$id-build-app-bundle.yml" })
    if ($preferred.Count -eq 0) { $preferred = @($candidates | Where-Object { $_.name -match 'build-app-bundle\.ya?ml$' }) }
    if ($preferred.Count -eq 0) { $preferred = $candidates }
    $wfPath = $null; $wfText = $null
    foreach ($c in $preferred) {
      $blob = TryApi "https://api.github.com/repos/$repo/git/blobs/$($c.sha)"
      if (-not $blob) { continue }
      $text = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($blob.content -replace '\s', '')))
      if ($text -match "APP_ID:\s*[`"']?$([regex]::Escape($id))[`"']?") { $wfPath = $c.path; $wfText = $text; break }
    }
    if (-not $wfPath) { throw "no workflow at $tag with APP_ID: $id" }

    $wfCommits = @((Api "https://api.github.com/repos/$repo/commits?path=$([uri]::EscapeDataString($wfPath))&sha=$([uri]::EscapeDataString($tag))&per_page=1") | ForEach-Object { $_ })
    $wfCommit = if ($wfCommits.Count -gt 0) { $wfCommits[0] } else { $commit }
    $wfSha = Get-LfSha256 $wfText

    $assetPlatforms = @(); $sizes = @{}
    foreach ($a in @($rel.assets)) {
      if ($a.name -match "^$([regex]::Escape($id))-.*-(win-x64|mac-arm64)\.zip$") {
        $p = $Matches[1]
        if ($assetPlatforms -notcontains $p) { $assetPlatforms += $p }
        $sizes[$p] = [math]::Round($a.size / 1MB)
      }
    }
    if ($assetPlatforms.Count -eq 0) { throw "no platform assets on $repo@$tag" }
    $assetPlatforms = @($assetPlatforms | Sort-Object { if ($_ -eq 'win-x64') { 0 } elseif ($_ -eq 'mac-arm64') { 1 } else { 2 } })
    $platforms = $assetPlatforms -join ', '
    $sizeParts = @($assetPlatforms | ForEach-Object { "$_=$($sizes[$_])" })

    $upstream = $repo
    $repoInfo = TryApi "https://api.github.com/repos/$repo"
    if ($repoInfo -and $repoInfo.fork -and $repoInfo.parent.full_name) {
      $upstream = $repoInfo.parent.full_name
    } elseif ($e.homepage -match '^https?://github\.com/([^/]+)/([^/#?]+)') {
      $cand = "$($Matches[1])/$($Matches[2])"
      if ($cand -ne $repo) { $upstream = $cand }
    }
    if ($upstream -ne $repo) {
      $upHead = @((Api "https://api.github.com/repos/$upstream/commits?per_page=1") | ForEach-Object { $_ })[0]
      $upSha = $upHead.sha
    } else {
      $upSha = $commit.sha
    }

    $name = $e.name; if (-not $name) { $name = EnvValue $wfText 'APP_NAME'; if (-not $name) { $name = $id } }
    $license = $e.license; if (-not $license) { $license = 'unknown' }
    $mode = EnvValue $wfText 'APP_MODE'; if (-not $mode) { $mode = 'auto' }
    $extra = EnvValue $wfText 'EXTRA_PKGS'
    $soft = EnvValue $wfText 'SOFT_PKGS'
    $archive = EnvValue $wfText 'ARCHIVE_URLS'
    $rebuild = EnvValue $wfText 'SOURCE_REBUILD'
    $notesEnv = EnvValue $wfText 'APP_NOTES'
    $subdir = EnvValue $wfText 'APP_SUBDIR'
    $builtAt = if ($rel.published_at) { $rel.published_at } else { $commit.commit.committer.date }
    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $version = $tag -replace '^v', ''
    $extraCount = @($extra -split '\s+' | Where-Object { $_ }).Count
    $archiveCount = @($archive -split '\s+' | Where-Object { $_ }).Count

    $decisions = @()
    if ($mode -ne 'auto') { $decisions += "APP_MODE=$mode - app layout from the generated workflow" }
    if ($extraCount -gt 0) { $decisions += "EXTRA_PKGS=$extraCount packages - extra dependencies declared in the workflow" }
    if ($soft) { $decisions += "SOFT_PKGS=$soft - optional/unavailable, not bundled" }
    if ($archiveCount -gt 0) { $decisions += "ARCHIVE_URLS=$archiveCount source tarball(s) - packages outside CRAN/Bioconductor" }
    if ($rebuild) { $decisions += "SOURCE_REBUILD=$rebuild - rebuilt from source for macOS" }
    if ($subdir -and $subdir -ne '.') { $decisions += "APP_SUBDIR=$subdir - app lives in a subdirectory" }
    if (-not $decisions) { $decisions = @('no non-default settings - generated from the stock template') }
    $decisionLines = ($decisions | ForEach-Object { "  - $_" }) -join "`n"

    $meta = @"
id: $id
name: $name
status: $Status
upstream: $upstream
fork: $repo
license: $license
app_mode: $mode
platforms: $platforms
version: $version
tag: $tag
release_url: https://github.com/$repo/releases/tag/$tag
build_run: ""
template: unknown (backfill)
patch_file: ""
recorded_at: $(Get-Date -Format 'yyyy-MM-dd')
built_at: $builtAt
source_repo: $repo
source_commit: $($commit.sha)
upstream_repo: $upstream
upstream_head: $upSha
upstream_checked_at: $now
workflow_path: $wfPath
workflow_commit: $($wfCommit.sha)
workflow_sha256: $wfSha
app_size_mb: $($sizeParts -join ', ')
closure_packages: ""
decisions:
$decisionLines
"@

    $artifactLines = (@($assetPlatforms) | ForEach-Object { "  - ``$id-$version-$_.zip`` ($($sizes[$_]) MB)" }) -join "`n"
    $extraDisplay = if ($extra) { ($extra -split '\s+' | Where-Object { $_ } | Select-Object -First 12) -join ', '; if ($extraCount -gt 12) { ", ... ($extraCount total)" } } else { '(none)' }
    $notes = @"
# $name (``$id``)

- **Status:** ``$Status`` -- backfilled from the published release; see ``meta.yml`` for provenance.
- **Upstream:** https://github.com/$upstream
- **Fork:** https://github.com/$repo
- **Release:** https://github.com/$repo/releases/tag/$tag (``$tag``)
- **Artifacts:**
$artifactLines
- **Template:** unknown (backfill from catalog); the workflow is a snapshot, not a template.

> If ``status`` is ``rejected`` or ``withdrawn``: **do not redistribute this bundle.**

## Why it is packaged this way

| Setting | Value |
|---|---|
| ``APP_MODE`` | ``$mode`` |
| ``EXTRA_PKGS`` | $extraDisplay |
| ``SOFT_PKGS`` | $(if ($soft) { $soft } else { '(none)' }) |
| ``ARCHIVE_URLS`` | $archiveCount source tarball(s) |
| ``SOURCE_REBUILD`` | $(if ($rebuild) { $rebuild } else { '(none)' }) |

## Known limitations

$(if ($notesEnv) { $notesEnv } else { '(none recorded; the workflow did not declare APP_NOTES)' })

## Debug log

Backfilled on $(Get-Date -Format 'yyyy-MM-dd') from the release assets; no run-by-run history
is available for this app. Add rows here when it is rebuilt.

## Reuse notes

Use the archived workflow and ``meta.yml`` decisions as a reference; redo the dependency
census for a different app instead of copying these values.
"@

    if ($DryRun) {
      Write-Host "[dry] $id $tag $platforms -> apps/$id"
      continue
    }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'build-app-bundle.yml'), ($wfText -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $dir 'meta.yml'), $meta, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $dir 'NOTES.md'), $notes, (New-Object Text.UTF8Encoding($false)))
    $ok++
    Write-Host ("[ok] {0,-24} {1,-10} {2}" -f $id, $tag, $platforms) -ForegroundColor Green
  } catch {
    $failed++
    Write-Host ("[fail] {0} : {1}" -f $id, $_.Exception.Message) -ForegroundColor Red
  }
}
Write-Host "backfill: $ok created, $skipped skipped, $failed failed"
