<#
  new-app-record.ps1 -- scaffold apps/<id>/ from apps/_template and copy the workflow.

  Usage:
    .\scripts\new-app-record.ps1 -AppId myapp -Name "My App" `
      -Upstream owner/repo -Fork <you>/repo -License MIT `
      -Platforms "win-x64, mac-arm64" -Tag v0.1.0 `
      -WorkflowPath .\myapp-build-app-bundle.yml
#>
param(
  [Parameter(Mandatory = $true)][string]$AppId,
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$Upstream,
  [Parameter(Mandatory = $true)][string]$Fork,
  [string]$License = 'unknown',
  [string]$Platforms = 'win-x64, mac-arm64',
  [string]$Tag = 'v0.1.0',
  [ValidateSet('active', 'pending', 'rejected', 'withdrawn', 'abandoned')][string]$Status = 'pending',
  [string]$AppMode = 'flat',
  [string]$WorkflowPath = '',
  [string]$PatchFile = '',
  [string]$Template = 'unknown',
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
if ($AppId -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "AppId must match ^[a-z0-9][a-z0-9-]*$" }

$appsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'apps'
$dir = Join-Path $appsDir $AppId
if ((Test-Path -LiteralPath $dir) -and -not $Force) { throw "apps/$AppId already exists (use -Force to overwrite)" }
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$version = $Tag -replace '^v', ''
$meta = Get-Content -LiteralPath (Join-Path $appsDir '_template/meta.yml') -Raw
$meta = $meta.Replace('id: example-id', "id: $AppId")
$meta = $meta.Replace('name: Example App', "name: $Name")
$meta = $meta.Replace('status: pending', "status: $Status")
$meta = $meta.Replace('upstream: owner/repo', "upstream: $Upstream")
$meta = $meta.Replace('fork: owner/repo', "fork: $Fork")
$meta = $meta.Replace('license: MIT', "license: $License")
$meta = $meta.Replace('app_mode: flat', "app_mode: $AppMode")
$meta = $meta.Replace('platforms: win-x64, mac-arm64', "platforms: $Platforms")
$meta = $meta.Replace('version: 0.1.0', "version: $version")
$meta = $meta.Replace('tag: v0.1.0', "tag: $Tag")
$meta = $meta.Replace('https://github.com/owner/repo/releases/tag/v0.1.0', "https://github.com/$Fork/releases/tag/$Tag")
$meta = $meta.Replace('template: pre-hardening', "template: $Template")
$meta = $meta.Replace('patch_file: ""', "patch_file: `"$PatchFile`"")
$meta = $meta.Replace('recorded_at: 2026-01-01', "recorded_at: $(Get-Date -Format 'yyyy-MM-dd')")
[IO.File]::WriteAllText((Join-Path $dir 'meta.yml'), $meta, (New-Object Text.UTF8Encoding($false)))

$notes = Get-Content -LiteralPath (Join-Path $appsDir '_template/NOTES.md') -Raw
$notes = $notes.Replace('<Name>', $Name).Replace('`<id>`', "``$AppId``").Replace('<status>', $Status)
$notes = $notes.Replace('<upstream-url>', "https://github.com/$Upstream")
$notes = $notes.Replace('<fork-url>', "https://github.com/$Fork")
$notes = $notes.Replace('<release-url>', "https://github.com/$Fork/releases/tag/$Tag")
$notes = $notes.Replace('<tag>', $Tag)
$notes = $notes.Replace('<template version>', $Template)
[IO.File]::WriteAllText((Join-Path $dir 'NOTES.md'), $notes, (New-Object Text.UTF8Encoding($false)))

if ($WorkflowPath) {
  if (-not (Test-Path -LiteralPath $WorkflowPath)) { throw "workflow not found: $WorkflowPath" }
  Copy-Item -LiteralPath $WorkflowPath -Destination (Join-Path $dir 'build-app-bundle.yml') -Force
  Write-Host "copied workflow from $WorkflowPath"
} else {
  Write-Host 'no -WorkflowPath: build-app-bundle.yml is missing (validate-apps will report it)' -ForegroundColor Yellow
}
Write-Host "created apps/$AppId"
