<#
  validate-apps.ps1 -- structural checks for apps/<id>/ records.

  Usage:
    .\scripts\validate-apps.ps1
    .\scripts\validate-apps.ps1 -CatalogPath ..\ShinyApps\catalog\apps.yml

  Errors fail the run (exit 1). Warnings are reported but do not fail it.
  The catalog check is optional and only compares statuses; it is not a network call.
#>
param(
  [string]$AppsDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'apps'),
  [string]$CatalogPath = ''
)
$ErrorActionPreference = 'Stop'

$errors   = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$statuses = @('active', 'pending', 'rejected', 'withdrawn', 'abandoned')
$required = @('id', 'name', 'status', 'upstream', 'license', 'app_mode', 'platforms', 'version', 'tag', 'template', 'recorded_at')

function Read-Meta([string]$Path) {
  $h = @{}
  foreach ($raw in Get-Content -LiteralPath $Path) {
    $line = $raw.TrimEnd()
    if ($line -match '^\s*(#|$)') { continue }
    if ($line -match '^\s*-\s') { continue }
    if ($line -match '^([A-Za-z0-9_]+):\s*(.*)$') {
      $key = $Matches[1]
      $val = ($Matches[2] -replace '\s+#.*$', '').Trim().Trim('"').Trim("'")
      $h[$key] = $val
    }
  }
  return $h
}

if (-not (Test-Path -LiteralPath $AppsDir)) { throw "apps directory not found: $AppsDir" }
$dirs = @(Get-ChildItem -LiteralPath $AppsDir -Directory | Where-Object { $_.Name -ne '_template' })
if ($dirs.Count -eq 0) { $warnings.Add('no app records found'); }

$ids = @{}
foreach ($d in $dirs) {
  $id = $d.Name
  $where = "apps/$id"
  if ($id -notmatch '^[a-z0-9][a-z0-9-]*$') { $errors.Add("${where}: folder name is not a valid store id") }
  if ($ids.ContainsKey($id)) { $errors.Add("${where}: duplicate id") } else { $ids[$id] = $true }

  $metaPath = Join-Path $d.FullName 'meta.yml'
  $wfPath   = Join-Path $d.FullName 'build-app-bundle.yml'
  $notes    = Join-Path $d.FullName 'NOTES.md'
  if (-not (Test-Path -LiteralPath $metaPath)) { $errors.Add("${where}: meta.yml missing"); continue }
  if (-not (Test-Path -LiteralPath $wfPath))   { $errors.Add("${where}: build-app-bundle.yml missing") }
  if (-not (Test-Path -LiteralPath $notes))    { $warnings.Add("${where}: NOTES.md missing") }

  $m = Read-Meta $metaPath
  foreach ($k in $required) {
    if (-not $m.ContainsKey($k) -or [string]::IsNullOrWhiteSpace($m[$k])) { $errors.Add("${where}: meta.yml missing '$k'") }
  }
  if ($m['id'] -and $m['id'] -ne $id) { $errors.Add("${where}: meta.yml id '$($m['id'])' != folder") }
  if ($m['status'] -and ($statuses -notcontains $m['status'])) {
    $errors.Add("${where}: status '$($m['status'])' not in $($statuses -join ', ')")
  }
  if ($m['tag'] -and $m['tag'] -notmatch '^v[0-9]') { $errors.Add("${where}: tag '$($m['tag'])' should look like v1.2.3") }
  if ($m['version'] -and $m['tag'] -and $m['tag'] -ne "v$($m['version'])") {
    $errors.Add("${where}: tag '$($m['tag'])' != v$($m['version'])")
  }
  if ($m['platforms']) {
    foreach ($p in ($m['platforms'] -split ',')) {
      $p = $p.Trim()
      if ($p -and @('win-x64', 'mac-arm64') -notcontains $p) { $errors.Add("${where}: unknown platform '$p'") }
    }
  }
  if ($m['patch_file']) {
    $pf = Join-Path $d.FullName $m['patch_file']
    if (-not (Test-Path -LiteralPath $pf)) { $errors.Add("${where}: patch_file '$($m['patch_file'])' not found") }
  }

  if (Test-Path -LiteralPath $wfPath) {
    $wf = Get-Content -LiteralPath $wfPath -Raw
    if ($wf -match '__[A-Z0-9_]+__') { $errors.Add("${where}: workflow still contains __PLACEHOLDER__ tokens") }
    if ($wf -notmatch '(?m)^name:\s*\S') { $errors.Add("${where}: workflow has no name:") }
    if ($wf -notmatch '(?m)^\s+APP_ID:\s*"?' + [regex]::Escape($id) + '"?' ) {
      $errors.Add("${where}: workflow APP_ID does not match '$id'")
    }
    if ($wf -notmatch 'upload-artifact') { $warnings.Add("${where}: workflow does not upload artifacts") }
    if ($wf -notmatch 'Smoke test') { $warnings.Add("${where}: workflow has no smoke test step") }
    if ($wf -match 'ghp_[A-Za-z0-9]{20,}' -or $wf -match 'github_pat_[A-Za-z0-9_]{20,}' -or $wf -match '(?i)password\s*=') {
      $errors.Add("${where}: workflow appears to contain a credential")
    }
  }
}

if ($CatalogPath) {
  if (-not (Test-Path -LiteralPath $CatalogPath)) {
    $warnings.Add("catalog not found, skipping comparison: $CatalogPath")
  } else {
    $listed = @{}
    foreach ($line in Get-Content -LiteralPath $CatalogPath) {
      if ($line -match '^\s*-\s*id:\s*([A-Za-z0-9-]+)') { $listed[$Matches[1]] = $true }
    }
    foreach ($id in $ids.Keys) {
      $m = Read-Meta (Join-Path (Join-Path $AppsDir $id) 'meta.yml')
      $inCatalog = $listed.ContainsKey($id)
      if ($m['status'] -eq 'active' -and -not $inCatalog) { $errors.Add("apps/${id}: status active but not in the catalog") }
      if ($m['status'] -ne 'active' -and $inCatalog) { $errors.Add("apps/${id}: status '$($m['status'])' but the app is in the catalog") }
    }
    $missing = @($listed.Keys | Where-Object { -not $ids.ContainsKey($_) })
    if ($missing.Count -gt 0) {
      $warnings.Add("catalog lists $($missing.Count) app(s) without a record (expected while records are backfilled)")
    }
  }
}

$warnings | ForEach-Object { Write-Host "WARN  $_" -ForegroundColor Yellow }
if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Host "ERROR $_" -ForegroundColor Red }
  Write-Host "validate-apps: $($errors.Count) error(s), $($warnings.Count) warning(s)"
  exit 1
}
Write-Host "validate-apps: OK ($($dirs.Count) record(s), $($warnings.Count) warning(s))" -ForegroundColor Green
