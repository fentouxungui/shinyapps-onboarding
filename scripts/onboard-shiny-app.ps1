<#
  onboard-shiny-app.ps1
  ---------------------
  Onboard any Shiny-app GitHub repo into the ShinyApps desktop app store
  (https://github.com/fentouxungui/ShinyApps), end to end:

    fork -> bundle workflow -> tag/release -> catalog entry + icon -> optional PR.

  Prerequisites
    * git on PATH, and a stored GitHub credential for https://github.com with the
      `repo` + `workflow` scopes (e.g. via Git Credential Manager).
    * templates/ under  assets/  (build-app-bundle.yml, catalog-entry.yml).
    * a 512x512 PNG icon for the app (-IconPath).

  App shapes (see https://github.com/fentouxungui/shinyapps-onboarding):
    * flat           : -AppMode flat           -AppSubdir <app dir>
    * package-fn     : -AppMode package-fn     -PkgSubdir <pkg root> -EntryFn 'library(pkg); pkg::fn(...)'
    * package-deploy : -AppMode package-deploy -AppSubdir <dir in inst/> -UiLibs ... -ServerLibs ...
                       -DemoRda <repo .rda> -DemoObject <name> -DemoSaveAs .SHINYSTAN_OBJECT

  Always bump -Tag for any change: installed clients only see an Update when the
  catalog version changes.
#>
param(
  [Parameter(Mandatory=$true)][string]$ShinyAppsOwner,
  [string]$ShinyAppsRepo = "ShinyApps",
  [Parameter(Mandatory=$true)][string]$Upstream,              # owner/name
  [Parameter(Mandatory=$true)][string]$AppId,                 # ^[a-z0-9][a-z0-9-]*$
  [Parameter(Mandatory=$true)][string]$AppName,
  [string]$AppAuthor = "", [string]$AppDesc = "", [string]$AppHomepage = "", [string]$AppLicense = "",
  [string]$AppDocs = "", [string]$AppCopyright = "", [string]$AppTags = "",
  [string]$AppMode = "auto", [string]$AppSubdir = ".", [string]$PkgSubdir = ".",
  [string]$EntryFn = "", [string]$UiLibs = "", [string]$ServerLibs = "",
  [string]$DemoRda = "", [string]$DemoObject = "", [string]$DemoSaveAs = "", [string]$DemoRdata = "",
  [string]$ExtraPkgs = "", [string]$Exclude = "rsconnect,.github", [string]$ArchiveUrls = "",
  [string]$ExtraRepos = "", [string]$SoftPkgs = "", [string]$SourceRebuild = "", [string]$AppNotes = "",
  [string]$Tag = "v0.1.0", [string]$RVersion = "4.6.1",
  [string]$IconPath = "", [string]$WorkDir = ".",
  [switch]$OpenPR, [switch]$WatchRelease
)
$ErrorActionPreference = "Stop"
function Info($m){ Write-Host "[onboard] $m" -ForegroundColor Cyan }

# --- token (repo + workflow scopes) -----------------------------------------
$cred = "protocol=https`nhost=github.com`n" | git credential fill 2>$null
$env:GH_TOKEN = (($cred | Where-Object { $_ -like 'password=*' }) -replace '^password=','')
if (-not $env:GH_TOKEN) { throw "No stored GitHub credential for https://github.com" }
$H = @{ Authorization = "token $env:GH_TOKEN"; "User-Agent" = "onboard-shiny-app"; Accept = "application/vnd.github+json" }
function Api($method,$uri,$json){
  if ($json) { $bytes=[Text.Encoding]::UTF8.GetBytes(($json|ConvertTo-Json -Depth 6)) }
  if ($bytes) { return Invoke-RestMethod -Method $method -Uri $uri -Headers $H -Body $bytes -ContentType 'application/json; charset=utf-8' }
  return Invoke-RestMethod -Method $method -Uri $uri -Headers $H
}
$LFS = @('-c','filter.lfs.process=','-c','filter.lfs.smudge=','-c','filter.lfs.clean=','-c','filter.lfs.required=false')

$owner, $repo = $Upstream.Split('/',2)
$RepoName = $repo
$me = (Api GET "https://api.github.com/user").login

# --- fork -------------------------------------------------------------------
try { $fork = Api GET "https://api.github.com/repos/$me/$RepoName" } catch { $fork = $null }
if (-not $fork) { Info "forking $Upstream ..."; Api POST "https://api.github.com/repos/$Upstream/forks" @{ default_branch_only=$true } | Out-Null }
for ($i=0; $i -lt 30; $i++) { try { $fork = Api GET "https://api.github.com/repos/$me/$RepoName"; break } catch { Start-Sleep 3 } }
$branch = $fork.default_branch
Info "fork ready: $me/$RepoName (default=$branch)"

# --- workflow ---------------------------------------------------------------
$dir = Join-Path $WorkDir "$AppId-fork"
if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
git @LFS clone --depth 1 -q "https://github.com/$me/$RepoName.git" $dir
$tpl = Get-Content (Join-Path $PSScriptRoot 'assets\build-app-bundle.yml') -Raw
$map = [ordered]@{
  '__APP_ID__'=$AppId;'__APP_NAME__'=$AppName;'__APP_AUTHOR__'=$AppAuthor;'__APP_DESC__'=$AppDesc
  '__APP_HOMEPAGE__'=$AppHomepage;'__APP_LICENSE__'=$AppLicense
  '__APP_SUBDIR__'=$AppSubdir;'__PKG_SUBDIR__'=$PkgSubdir;'__ENTRY_FN__'=$EntryFn
  '__UI_LIBS__'=$UiLibs;'__SERVER_LIBS__'=$ServerLibs
  '__DEMO_RDA__'=$DemoRda;'__DEMO_OBJECT__'=$DemoObject;'__DEMO_SAVE_AS__'=$DemoSaveAs;'__DEMO_RDATA__'=$DemoRdata
  '__EXTRA_PKGS__'=$ExtraPkgs;'__EXCLUDE__'=$Exclude;'__ARCHIVE_URLS__'=$ArchiveUrls
  '__EXTRA_REPOS__'=$ExtraRepos;'__SOFT_PKGS__'=$SoftPkgs;'__SOURCE_REBUILD__'=$SourceRebuild
  '__APP_NOTES__'=$AppNotes;'__R_VERSION__'=$RVersion
}
foreach ($k in $map.Keys) { $tpl = $tpl.Replace($k, [string]$map[$k]) }
$wfdir = Join-Path $dir ".github\workflows"
New-Item -ItemType Directory -Force -Path $wfdir | Out-Null
$enc = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $wfdir "$AppId-build-app-bundle.yml"), $tpl, $enc)
git -C $dir add ".github/workflows/$AppId-build-app-bundle.yml"
git -C $dir commit -q -m "Add GitHub Actions workflow publishing prebuilt desktop app bundles (ShinyApps store)"
git -C $dir push -q -u origin $branch
Info "workflow pushed to $me/$RepoName@$branch"

# --- tag -> release CI ------------------------------------------------------
git -C $dir tag -a $Tag -m "$AppName ShinyApps bundle $Tag"
git -C $dir push -q origin $Tag
Info "tag $Tag pushed (CI building bundles)"

if ($WatchRelease) {
  do { Start-Sleep 20; $run = (Api GET "https://api.github.com/repos/$me/$RepoName/actions/runs?per_page=1").workflow_runs[0] }
  while ($run.status -ne 'completed')
  if ($run.conclusion -ne 'success') { throw "bundle CI $($run.conclusion): $($run.html_url)" }
  $rel = Api GET "https://api.github.com/repos/$me/$RepoName/releases/tags/$Tag"
  Info ("release assets: " + (($rel.assets | ForEach-Object { "$($_.name) ($([math]::Round($_.size/1MB,1)) MB)" }) -join ', '))
}

# --- catalog entry + icon -> ShinyApps --------------------------------------
$sa = Join-Path $WorkDir "$ShinyAppsRepo-sa"
if (Test-Path $sa) { Remove-Item -Recurse -Force $sa }
git @LFS clone --depth 1 -q "https://github.com/$ShinyAppsOwner/$ShinyAppsRepo.git" $sa
$apps = Join-Path $sa "catalog\apps.yml"
if ((Get-Content $apps -Raw) -notmatch "id:\s*$AppId\b") {
  $cat = Get-Content (Join-Path $PSScriptRoot 'assets\catalog-entry.yml') -Raw
  $cmap = [ordered]@{'__APP_ID__'=$AppId;'__SHINYAPPS_OWNER__'=$ShinyAppsOwner;'__REPO_NAME__'=$RepoName
    '__APP_NAME__'=$AppName;'__APP_AUTHOR__'=$AppAuthor;'__APP_DESC__'=$AppDesc;'__APP_HOMEPAGE__'=$AppHomepage
    '__DOCS__'=$AppDocs;'__COPYRIGHT__'=$AppCopyright;'__LICENSE__'=$AppLicense;'__R_VERSION__'=$RVersion;'__TAGS__'=$AppTags}
  foreach ($k in $cmap.Keys) { $cat = $cat.Replace($k,[string]$cmap[$k]) }
  $raw = [IO.File]::ReadAllText($apps).TrimEnd("`r","`n"," ","`t") + "`n`n" + $cat
  [IO.File]::WriteAllText($apps, $raw, (New-Object Text.UTF8Encoding($false)))
  if ($IconPath) { Copy-Item $IconPath (Join-Path $sa "icons\$AppId.png") -Force }
  git -C $sa add catalog/apps.yml "icons/$AppId.png"
  git -C $sa commit -q -m "catalog: add $AppName"
  git -C $sa push -q origin HEAD
  Info "catalog entry + icon pushed to $ShinyAppsOwner/$ShinyAppsRepo"
} else { Info "catalog already contains $AppId; skipping" }

# --- upstream PR ------------------------------------------------------------
if ($OpenPR) {
  $existing = Api GET "https://api.github.com/repos/$Upstream/pulls" | Where-Object { $_.head.label -eq "${me}:${branch}" }
  if (-not $existing) {
    $pr = Api POST "https://api.github.com/repos/$Upstream/pulls" @{
      title = "Add a GitHub Actions workflow publishing prebuilt desktop app bundles (ShinyApps store)"
      head  = "${me}:${branch}"; base = $branch
      body  = "Adds `.github/workflows/$AppId-build-app-bundle.yml`, a CI-only workflow that builds prebuilt desktop bundles for the ShinyApps store. No application source is changed."
      maintainer_can_modify = $true
    }
    Info "PR opened: $($pr.html_url)"
  } else { Info "PR already open: $($existing.html_url)" }
}
Info "done."
