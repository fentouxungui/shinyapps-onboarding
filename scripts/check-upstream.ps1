<#
  check-upstream.ps1 -- weekly drift report for apps/<id>/ records.

  For every record it compares the pinned snapshot with the fork and the upstream repo:
    * fork workflow vs the archived snapshot (by sha256)  -> workflow-drift
    * upstream release/tag vs the recorded tag            -> rebuild
    * upstream commits touching app files since the last record -> rebuild
    * fork behind upstream                                -> sync-first
  It writes site/status.json for the dashboard; it never edits apps/.

  Usage:
    .\scripts\check-upstream.ps1 -OutFile ..\site\status.json
    $env:GITHUB_TOKEN = '...'; .\scripts\check-upstream.ps1 -DryRun

  Requires a GitHub token (GITHUB_TOKEN) or a stored credential for github.com.
#>
param(
  [string]$AppsDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'apps'),
  [string]$OutFile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'site/status.json'),
  [string]$Token = '',
  [switch]$SkipFork,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

$tok = $Token
if (-not $tok) { $tok = $env:GITHUB_TOKEN }
if (-not $tok) {
  $cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
  $tok = (($cred | Where-Object { $_ -like 'password=*' }) -replace '^password=','')
}
if (-not $tok) { throw 'No GitHub token: set GITHUB_TOKEN or store a credential for github.com' }
$H = @{ Authorization = "token $tok"; 'User-Agent' = 'shinyapps-onboarding'; Accept = 'application/vnd.github+json' }

function Api([string]$Uri) { Invoke-RestMethod -Uri $Uri -Headers $H -TimeoutSec 60 }
function TryApi([string]$Uri) { try { Api $Uri } catch { $null } }
function Read-Meta([string]$Path) {
  $h = @{}
  foreach ($raw in Get-Content -LiteralPath $Path) {
    $line = $raw.TrimEnd()
    if ($line -match '^\s*(#|$)') { continue }
    if ($line -match '^\s*-\s') { continue }
    if ($line -match '^([A-Za-z0-9_]+):\s*(.*)$') {
      $h[$Matches[1]] = ($Matches[2] -replace '\s+#.*$', '').Trim().Trim('"').Trim("'")
    }
  }
  return $h
}
function Get-LfSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes(($Text -replace "`r`n", "`n"))
  $h = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  (([BitConverter]::ToString($h)) -replace '-', '').ToLower()
}
function Test-AppPath([string]$Path) {
  if ($Path -match '^\.github/') { return $false }
  if ($Path -match '^docs?/') { return $false }
  if ($Path -match '^(?i)(README|LICENSE|COPYING|CHANGELOG|CONTRIBUTING|CODE_OF_CONDUCT)') { return $false }
  if ($Path -match '^(?i)(\.gitignore|\.Rbuildignore|\.github)') { return $false }
  return $true
}
function Test-Newer([string]$Candidate, [string]$Current) {
  $a = @((($Candidate -replace '^v', '') -split '[^0-9]+') | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
  $b = @((($Current -replace '^v', '') -split '[^0-9]+') | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
  if ($a.Count -eq 0 -or $b.Count -eq 0) { return $false }
  $n = [Math]::Max($a.Count, $b.Count)
  for ($i = 0; $i -lt $n; $i++) {
    $x = if ($i -lt $a.Count) { $a[$i] } else { 0 }
    $y = if ($i -lt $b.Count) { $b[$i] } else { 0 }
    if ($x -ne $y) { return ($x -gt $y) }
  }
  return $false
}
function Get-RawWorkflow([string]$Repo, [string]$Branch, [string]$Path) {
  $url = "https://raw.githubusercontent.com/$Repo/$Branch/$Path"
  try { return (Invoke-WebRequest -Uri $url -Headers @{ Authorization = "token $tok" } -UseBasicParsing -TimeoutSec 60).Content }
  catch { return $null }
}
function Get-RawWorkflowAny([string]$Repo, [string]$Path) {
  foreach ($b in @('main', 'master')) {
    $wf = Get-RawWorkflow $Repo $b $Path
    if ($wf) { return $wf }
  }
  $info = TryApi "https://api.github.com/repos/$Repo"
  if ($info -and $info.default_branch) { return Get-RawWorkflow $Repo $info.default_branch $Path }
  return $null
}

$results = @()
foreach ($d in Get-ChildItem -LiteralPath $AppsDir -Directory | Where-Object { $_.Name -ne '_template' }) {
  $metaPath = Join-Path $d.FullName 'meta.yml'
  if (-not (Test-Path -LiteralPath $metaPath)) { continue }
  $m = Read-Meta $metaPath
  $id = $d.Name
  $base = [ordered]@{
    id = $id; name = $m['name']; status = $m['status']; platforms = $m['platforms']
    version = $m['version']; tag = $m['tag']; built_at = $m['built_at']
    action = 'ok'; reasons = @()
    upstream = [ordered]@{ repo = $m['upstream_repo']; previous_head = $m['upstream_head']; head = ''; commits_since = $null; code_changed = $false; files = @(); latest_release = '' }
    fork = [ordered]@{ repo = $m['source_repo']; behind_by = $null; ahead_by = $null }
    workflow = [ordered]@{ path = $m['workflow_path']; changed = $null; sha256 = $m['workflow_sha256'] }
  }

  if (@('rejected', 'withdrawn') -contains $m['status']) {
    $base.action = 'withheld'
    $base.reasons = @('not distributed; no check')
    $results += [pscustomobject]$base
    Write-Host ("{0,-22} {1}" -f $id, 'withheld') -ForegroundColor DarkGray
    continue
  }

  $missing = @()
  foreach ($k in @('upstream_repo', 'upstream_head', 'source_repo', 'workflow_path', 'workflow_sha256', 'tag', 'built_at')) {
    if (-not $m[$k]) { $missing += $k }
  }
  if ($missing.Count -gt 0) {
    $base.action = 'unknown-meta'
    $base.reasons = @("missing fields: $($missing -join ', ')")
    $results += [pscustomobject]$base
    Write-Host ("{0,-22} {1}" -f $id, 'unknown-meta') -ForegroundColor DarkYellow
    continue
  }

  $upHead = @((Api "https://api.github.com/repos/$($m['upstream_repo'])/commits?per_page=1") | ForEach-Object { $_ })[0]
  $base.upstream.head = $upHead.sha

  if ($upHead.sha -ne $m['upstream_head']) {
    $cmp = TryApi "https://api.github.com/repos/$($m['upstream_repo'])/compare/$($m['upstream_head'])...$($upHead.sha)"
    if ($cmp) {
      $base.upstream.commits_since = $cmp.ahead_by
      $files = @($cmp.files | ForEach-Object { $_.filename })
      $appFiles = @($files | Where-Object { Test-AppPath $_ })
      $base.upstream.code_changed = ($appFiles.Count -gt 0)
      $base.upstream.files = @($appFiles | Select-Object -First 15)
      if ($appFiles.Count -gt 0) { $base.reasons += "$($appFiles.Count) app file(s) changed upstream" }
    } else {
      $base.reasons += 'upstream compare unavailable (force-push or deleted commit)'
    }
  }

  $rel = TryApi "https://api.github.com/repos/$($m['upstream_repo'])/releases?per_page=1"
  if ($rel -and @($rel).Count -gt 0) {
    $latest = @($rel)[0]
    $base.upstream.latest_release = $latest.tag_name
    if ($latest.published_at -and $m['built_at']) {
      try {
        if ([datetimeoffset]::Parse($latest.published_at) -gt [datetimeoffset]::Parse($m['built_at'])) {
          $base.reasons += "upstream release $($latest.tag_name) was published after this bundle"
        }
      } catch { }
    }
  }

  if (-not $SkipFork) {
    $isFork = ($m['source_repo'] -ne $m['upstream_repo'])
    if ($isFork) {
      $forkHead = @((Api "https://api.github.com/repos/$($m['source_repo'])/commits?per_page=1") | ForEach-Object { $_ })[0]
      $fcmp = TryApi "https://api.github.com/repos/$($m['upstream_repo'])/compare/$($upHead.sha)...$($forkHead.sha)"
      if ($fcmp) {
        $base.fork.behind_by = $fcmp.behind_by
        $base.fork.ahead_by = $fcmp.ahead_by
        if ($fcmp.behind_by -gt 0) { $base.reasons += "fork is $($fcmp.behind_by) commit(s) behind upstream" }
      }
    }
    $rawWf = Get-RawWorkflowAny $m['source_repo'] $m['workflow_path']
    if ($rawWf) {
      $base.workflow.changed = ((Get-LfSha256 $rawWf) -ne $m['workflow_sha256'])
      if ($base.workflow.changed) { $base.reasons += 'workflow differs from the snapshot' }
    }
  }

  $rebuild = $base.reasons | Where-Object { $_ -match 'app file|published after this bundle' }
  if ($base.fork.behind_by -gt 0) { $base.action = 'sync-first' }
  elseif ($rebuild) { $base.action = 'rebuild' }
  elseif ($base.workflow.changed -eq $true) { $base.action = 'workflow-drift' }
  elseif ($base.upstream.head -eq '') { $base.action = 'unknown' }
  else { $base.action = 'ok' }
  if ($base.reasons.Count -eq 0) { $base.reasons = @('no change since the last record') }

  $results += [pscustomobject]$base
  $color = switch ($base.action) { 'ok' { 'Green' } 'workflow-drift' { 'Yellow' } 'rebuild' { 'Cyan' } 'sync-first' { 'Magenta' } default { 'DarkYellow' } }
  Write-Host ("{0,-22} {1,-14} {2}" -f $id, $base.action, ($base.reasons -join '; ')) -ForegroundColor $color
}

$doc = [ordered]@{ generated_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); apps = @($results) }
$json = $doc | ConvertTo-Json -Depth 8
if ($DryRun) { Write-Host $json; return }
$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($OutFile, $json, (New-Object Text.UTF8Encoding($false)))
Write-Host "wrote $OutFile ($($results.Count) apps)"
