<#
  next-pkg-version.ps1 -- allocate a unique build-time version suffix for a package.

  The ShinyApps shell moves package directories into a shared library keyed by
  name+version. Two apps that bundle the same package version but different vendored
  libraries can overwrite each other. Apps that ship such a package (e.g. Cairo with
  vendored XQuartz dylibs) must append a unique numeric suffix at build time.

  Usage:
    .\scripts\next-pkg-version.ps1 -Package Cairo -List
    .\scripts\next-pkg-version.ps1 -Package Cairo -AppId myapp -Reserve

  Registry: apps/pkg-versions.tsv (package, app, suffix, status, note).
#>
param(
  [Parameter(Mandatory = $true)][string]$Package,
  [string]$AppId = '',
  [switch]$Reserve,
  [switch]$List,
  [string]$Registry = (Join-Path (Split-Path $PSScriptRoot -Parent) 'apps/pkg-versions.tsv')
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Registry)) {
  [IO.File]::WriteAllText($Registry, "package`tapp`tsuffix`tstatus`tnote`n", (New-Object Text.UTF8Encoding($false)))
}
$rows = @(Import-Csv -LiteralPath $Registry -Delimiter "`t")
$mine = @($rows | Where-Object { $_.package -eq $Package })

if ($List) {
  if ($mine.Count -eq 0) { Write-Host "no versions registered for $Package" }
  else { $mine | Format-Table package, app, suffix, status, note -AutoSize | Out-String | Write-Host }
}
if ($Reserve) {
  if (-not $AppId) { throw '-Reserve needs -AppId' }
  if (@($mine | Where-Object { $_.app -eq $AppId }).Count -gt 0) {
    throw "$AppId already has a $Package row; edit $Registry if it must change"
  }
}
$used = @($mine | ForEach-Object { [int]$_.suffix })
$next = if ($used.Count -eq 0) { 9001 } else { ($used | Measure-Object -Maximum).Maximum + 1 }
if ($used -contains $next) { throw "suffix collision for ${Package}: $next" }

if ($Reserve) {
  $line = "$Package`t$AppId`t$next`treserved`tallocated $(Get-Date -Format 'yyyy-MM-dd')"
  [IO.File]::AppendAllText($Registry, "$line`n", (New-Object Text.UTF8Encoding($false)))
  Write-Host "reserved $Package suffix $next for $AppId"
  Write-Host "build with: -PkgVersionPackages `"$Package`" -PkgVersionSuffix `"$next`""
} else {
  Write-Host "next free $Package suffix: $next"
}
