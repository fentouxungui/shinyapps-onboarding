<#
  build-dashboard.ps1 -- render site/index.html from site/status.json.

  Maintenance board only: it shows drift/rebuild signals and links to the app records and
  the ShinyApps catalog. It is not a second app store.

  Usage:
    .\scripts\build-dashboard.ps1 -StatusPath ..\site\status.json -OutFile ..\site\index.html
#>
param(
  [string]$StatusPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'site/status.json'),
  [string]$OutFile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'site/index.html'),
  [string]$RepoUrl = 'https://github.com/fentouxungui/shinyapps-onboarding',
  [string]$CatalogUrl = 'https://fentouxungui.github.io/ShinyApps/catalog.json'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $StatusPath)) { throw "status file not found: $StatusPath" }
$doc = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$apps = @($doc.apps)

function HtmlEnc([string]$Text) {
  if ($null -eq $Text) { return '' }
  return ($Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

$counts = @{}
foreach ($a in $apps) { $k = $a.action; if (-not $counts.ContainsKey($k)) { $counts[$k] = 0 }; $counts[$k]++ }
$summary = ($counts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key): $($_.Value)" }) -join ' | '

$rows = New-Object System.Text.StringBuilder
foreach ($a in ($apps | Sort-Object { $_.action -ne 'ok' }, { $_.id })) {
  $status = if ($a.status) { $a.status } else { '' }
  $withheld = @('rejected', 'withdrawn') -contains $status
  $cls = if ($withheld) { ' class="withheld"' } else { '' }
  $style = if ($withheld) { ' style="display:none"' } else { '' }
  $name = if ($a.name) { $a.name } else { $a.id }
  $platforms = if ($a.platforms) { $a.platforms } else { '' }
  $built = if ($a.built_at) { $a.built_at } else { '' }
  $why = if ($a.reasons) { @($a.reasons) -join '; ' } else { '' }
  $notes = "$RepoUrl/blob/main/apps/$($a.id)/NOTES.md"
  $release = if ($a.tag -and $a.fork -and $a.fork.repo) { "https://github.com/$($a.fork.repo)/releases/tag/$($a.tag)" } else { '' }
  $upstream = if ($a.upstream -and $a.upstream.repo) { "https://github.com/$($a.upstream.repo)" } else { '' }
  $links = "<a href=`"$notes`">NOTES</a>"
  if ($release) { $links += " | <a href=`"$release`">release</a>" }
  if ($upstream) { $links += " | <a href=`"$upstream`">upstream</a>" }
  $search = HtmlEnc(("$($a.id) $name $($a.upstream.repo) $status $($a.action)").ToLower())
  [void]$rows.AppendLine("<tr$cls$style data-status=`"$(HtmlEnc $status)`" data-action=`"$(HtmlEnc $a.action)`" data-search=`"$search`">")
  [void]$rows.AppendLine("<td><strong>$(HtmlEnc $a.id)</strong><br><span class=`"muted`">$(HtmlEnc $name)</span></td>")
  [void]$rows.AppendLine("<td>$(HtmlEnc $status)</td><td>$(HtmlEnc $platforms)</td><td>$(HtmlEnc $built)</td>")
  [void]$rows.AppendLine("<td><span class=`"action a-$(HtmlEnc $a.action)`">$(HtmlEnc $a.action)</span></td>")
  [void]$rows.AppendLine("<td>$(HtmlEnc $why)</td><td>$links</td></tr>")
}

$html = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ShinyApps onboarding -- maintenance board</title>
<style>
:root { color-scheme: light dark; }
body { font: 14px/1.5 -apple-system, "Segoe UI", Roboto, sans-serif; margin: 24px; max-width: 1200px; }
h1 { font-size: 20px; margin: 0 0 4px; }
.muted { color: #777; font-size: 12px; }
.summary { margin: 12px 0; padding: 8px 12px; background: rgba(127,127,127,.1); border-radius: 6px; }
.filters { display: flex; gap: 8px; flex-wrap: wrap; margin: 16px 0; }
input, select { padding: 4px 8px; font: inherit; }
table { border-collapse: collapse; width: 100%; }
th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid rgba(127,127,127,.25); vertical-align: top; }
th { position: sticky; top: 0; background: Canvas; }
.action { font-variant: small-caps; font-weight: 600; }
.a-ok { color: #2e7d32; } .a-rebuild { color: #0277bd; } .a-workflow-drift { color: #b26a00; }
.a-sync-first { color: #7b1fa2; } .a-unknown, .a-unknown-meta { color: #777; }
tr:hover { background: rgba(127,127,127,.08); }
</style>
</head>
<body>
<h1>ShinyApps onboarding -- maintenance board</h1>
<p class="muted">Generated __GENERATED__. Snapshot records: <a href="__REPO__/tree/main/apps">apps/</a>.
Listing status belongs to the <a href="__CATALOG__">ShinyApps catalog</a>; this page only reports drift
and rebuild signals.</p>
<div class="summary">__SUMMARY__</div>
<div class="filters">
  <input id="q" placeholder="filter id, name, repo" size="28">
  <select id="action"><option value="">all actions</option></select>
  <select id="status"><option value="">all statuses</option></select>
  <label><input type="checkbox" id="withheld"> show withheld/rejected</label>
</div>
<table>
<thead><tr><th>app</th><th>status</th><th>platforms</th><th>last build</th><th>action</th><th>why</th><th>links</th></tr></thead>
<tbody>
__ROWS__
</tbody>
</table>
<script>
const rows = Array.from(document.querySelectorAll('tbody tr'));
const q = document.getElementById('q');
const fa = document.getElementById('action');
const fs = document.getElementById('status');
const withheld = document.getElementById('withheld');
function fill(sel, attr) {
  const vals = [...new Set(rows.map(r => r.dataset[attr]).filter(Boolean))].sort();
  vals.forEach(v => { const o = document.createElement('option'); o.value = v; o.textContent = v; sel.appendChild(o); });
}
fill(fa, 'action'); fill(fs, 'status');
function apply() {
  const term = q.value.trim().toLowerCase();
  rows.forEach(r => {
    let ok = !term || r.dataset.search.includes(term);
    if (ok && fa.value) ok = r.dataset.action === fa.value;
    if (ok && fs.value) ok = r.dataset.status === fs.value;
    if (ok && !withheld.checked && r.classList.contains('withheld')) ok = false;
    r.style.display = ok ? '' : 'none';
  });
}
[q, fa, fs, withheld].forEach(el => el.addEventListener('input', apply));
apply();
</script>
</body>
</html>
'@

$html = $html.Replace('__GENERATED__', (HtmlEnc $doc.generated_at))
$html = $html.Replace('__REPO__', (HtmlEnc $RepoUrl))
$html = $html.Replace('__CATALOG__', (HtmlEnc $CatalogUrl))
$html = $html.Replace('__SUMMARY__', (HtmlEnc $summary))
$html = $html.Replace('__ROWS__', $rows.ToString())

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($OutFile, $html, (New-Object Text.UTF8Encoding($false)))
Write-Host "wrote $OutFile ($($apps.Count) apps)"
