<#
  record-app.ps1 -- snapshot a released app into apps/<id>/.

  Pulls the workflow **at the release tag** (not from main), the release assets and the
  commit SHAs, then writes meta.yml + NOTES.md. The workflow copy is immutable: it is the
  file that produced that release. Later changes in the fork are reported by
  check-upstream.ps1 as drift; they never overwrite this snapshot.

  Usage:
    .\scripts\record-app.ps1 -AppId myapp -Fork you/myapp -Upstream owner/myapp -Tag v1.2.3

  Requires a GitHub token (GITHUB_TOKEN) or a stored credential for github.com.
#>
param(
  [Parameter(Mandatory = $true)][string]$AppId,
  [Parameter(Mandatory = $true)][string]$Fork,
  [Parameter(Mandatory = $true)][string]$Upstream,
  [Parameter(Mandatory = $true)][string]$Tag,
  [string]$Name = '',
  [string]$License = '',
  [string]$Platforms = '',
  [ValidateSet('active', 'pending', 'rejected', 'withdrawn', 'abandoned')][string]$Status = 'pending',
  [string]$Template = 'unknown',
  [string]$WorkflowPath = '',
  [string]$AppsDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'apps'),
  [switch]$Force,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
if ($AppId -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "AppId must match ^[a-z0-9][a-z0-9-]*$" }
if (-not $WorkflowPath) { $WorkflowPath = ".github/workflows/$AppId-build-app-bundle.yml" }

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

Write-Host "[record] $Fork@$Tag"
$release = TryApi "https://api.github.com/repos/$Fork/releases/tags/$Tag"
if (-not $release) { throw "No release for $Fork@$Tag. Publish the bundle first." }
$commit = Api "https://api.github.com/repos/$Fork/commits/$Tag"
$wfCommits = @(Api "https://api.github.com/repos/$Fork/commits?path=$([uri]::EscapeDataString($WorkflowPath))&sha=$Tag&per_page=1")
if ($wfCommits.Count -eq 0) {
  throw "Workflow $WorkflowPath was not present at $Tag. The release was not built by that file."
}
$wfCommit = $wfCommits[0]

$rawUrl = "https://raw.githubusercontent.com/$Fork/$Tag/$WorkflowPath"
try {
  $raw = (Invoke-WebRequest -Uri $rawUrl -Headers @{ Authorization = "token $tok" } -UseBasicParsing -TimeoutSec 60).Content
} catch {
  throw "Cannot fetch $rawUrl : $($_.Exception.Message)"
}
if (-not $raw -or $raw.Length -lt 200) { throw "Workflow content looks empty: $rawUrl" }
$wfText = $raw
$wfSha  = Get-LfSha256 $wfText

if (-not $Name)    { $Name = EnvValue $wfText 'APP_NAME'; if (-not $Name) { $Name = $AppId } }
if (-not $License) { $License = EnvValue $wfText 'APP_LICENSE'; if (-not $License) { $License = 'unknown' } }

$assetPlatforms = @()
$sizes = @{}
foreach ($a in @($release.assets)) {
  if ($a.name -match "^$([regex]::Escape($AppId))-.*-(win-x64|mac-arm64)\.zip$") {
    $p = $Matches[1]
    if ($assetPlatforms -notcontains $p) { $assetPlatforms += $p }
    $sizes[$p] = [math]::Round($a.size / 1MB)
  }
}
$assetPlatforms = @($assetPlatforms | Sort-Object { if ($_ -eq 'win-x64') { 0 } elseif ($_ -eq 'mac-arm64') { 1 } else { 2 } })
if ($assetPlatforms.Count -eq 0) {
  throw "No '<id>-<version>-<platform>.zip' assets on $Fork@$Tag. Check the asset prefix (it must be $AppId-...)."
}
if (-not $Platforms) { $Platforms = ($assetPlatforms -join ', ') }
$sizeParts = @($assetPlatforms | ForEach-Object { "$_=$($sizes[$_])" })

$upHead = @(Api "https://api.github.com/repos/$Upstream/commits?per_page=1")[0]
$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$builtAt = if ($release.published_at) { $release.published_at } else { $commit.commit.committer.date }
$version = $Tag -replace '^v', ''

$meta = @"
id: $AppId
name: $Name
status: $Status
upstream: $Upstream
fork: $Fork
license: $License
app_mode: $(EnvValue $wfText 'APP_MODE')
platforms: $Platforms
version: $version
tag: $Tag
release_url: https://github.com/$Fork/releases/tag/$Tag
build_run: ""
template: $Template
patch_file: ""
recorded_at: $(Get-Date -Format 'yyyy-MM-dd')
built_at: $builtAt
source_repo: $Fork
source_commit: $($commit.sha)
upstream_repo: $Upstream
upstream_head: $($upHead.sha)
upstream_checked_at: $now
workflow_path: $WorkflowPath
workflow_commit: $($wfCommit.sha)
workflow_sha256: $wfSha
app_size_mb: $($sizeParts -join ', ')
closure_packages: ""
decisions:
  - KEY=value - why it is set this way
"@

$dir = Join-Path $AppsDir $AppId
if ((Test-Path -LiteralPath (Join-Path $dir 'meta.yml')) -and -not $Force) {
  throw "apps/$AppId already exists (use -Force to overwrite the snapshot)"
}
$artifacts = ($assetPlatforms | ForEach-Object { '  - `{0}-{1}-{2}.zip` ({3} MB)' -f $AppId, $version, $_, $sizes[$_] }) -join "`n"
$statusText = switch ($Status) {
  'active'    { 'listed in the ShinyApps catalog' }
  'pending'   { 'bundle builds; not listed in the catalog yet' }
  'rejected'  { 'the author declined; do not redistribute' }
  'withdrawn' { 'was listed, removed on request or by decision' }
  'abandoned' { 'no usable bundle was produced' }
}
$notes = Get-Content -LiteralPath (Join-Path $AppsDir '_template/NOTES.md') -Raw
$notes = $notes -replace '(?s)-- <one sentence: .*?never built>', "-- $statusText"
$notes = $notes.Replace('<Name>', $Name).Replace('`<id>`', "``$AppId``").Replace('<status>', $Status)
$notes = $notes.Replace('<upstream-url>', "https://github.com/$Upstream")
$notes = $notes.Replace('<fork-url>', "https://github.com/$Fork")
$notes = $notes.Replace('<release-url>', "https://github.com/$Fork/releases/tag/$Tag")
$notes = $notes.Replace('<tag>', $Tag)
$notes = $notes.Replace('<template version>', $Template)
$oldArtifacts = "- **Artifacts:** one entry per platform listed in ``meta.yml``, e.g.`n  ``<id>-<version>-win-x64.zip`` (<N> MB)"
if ($notes.Contains($oldArtifacts) -and $artifacts) { $notes = $notes.Replace($oldArtifacts, "- **Artifacts:**`n$artifacts") }

if ($DryRun) {
  Write-Host '--- meta.yml (dry run) ---'; Write-Host $meta
  Write-Host '--- NOTES.md (dry run) ---'; Write-Host $notes
  return
}

New-Item -ItemType Directory -Force -Path $dir | Out-Null
[IO.File]::WriteAllText((Join-Path $dir 'build-app-bundle.yml'), ($raw -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText((Join-Path $dir 'meta.yml'), $meta, (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText((Join-Path $dir 'NOTES.md'), $notes, (New-Object Text.UTF8Encoding($false)))
Write-Host "created apps/$AppId (workflow $wfSha, $builtAt)" -ForegroundColor Green
