<#
.SYNOPSIS
  Export theme tokens to SCSS, Figma Tokens (JSON) and JavaScript.

.DESCRIPTION
  Reads every themes/<id>/tokens.json and writes:

    themes/export/scss/_<id>.scss          $<id>-<mode>-<token> variables
    themes/export/figma/<id>.tokens.json   Figma "Design Tokens" plugin format
    themes/export/js/<id>.js               ES module with the full token set

  Output is fully regenerable - the themes/export/ folder is gitignored.

.PARAMETER Theme
  Only export themes whose id matches this wildcard pattern.

.PARAMETER OutDir
  Output root. Default: <repo>/themes/export.

.EXAMPLE
  powershell -File tools/export-tokens.ps1
  powershell -File tools/export-tokens.ps1 -Theme dusk
#>
[CmdletBinding()]
param(
  [string]$Theme = "*",
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$themesDir = Join-Path $repoRoot "themes"
if (-not $OutDir) { $OutDir = Join-Path $themesDir "export" }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$scssDir = Join-Path $OutDir "scss"
$figmaDir = Join-Path $OutDir "figma"
$jsDir = Join-Path $OutDir "js"
foreach ($d in @($scssDir, $figmaDir, $jsDir)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

$colorKeys = @("bg", "surface", "surfaceRaised", "border", "text", "textMuted", "ring",
               "primary", "primaryHover", "primarySubtle",
               "secondary", "secondaryHover", "secondarySubtle",
               "accent", "accentHover", "accentSubtle",
               "success", "successSubtle", "warning", "warningSubtle",
               "error", "errorSubtle", "info", "infoSubtle")

$tokenFiles = Get-ChildItem -Path $themesDir -Directory | ForEach-Object {
  Join-Path $_.FullName "tokens.json"
} | Where-Object { Test-Path $_ } | Sort-Object

$exported = 0

function New-FigmaColorSet {
  param($colors)
  $o = New-Object PSObject
  foreach ($k in $colorKeys) {
    $v = $colors.$k
    if ($v) {
      $o | Add-Member -NotePropertyName $k -NotePropertyValue ([pscustomobject]@{ value = $v; type = "color" })
    }
  }
  return $o
}

foreach ($file in $tokenFiles) {
  $t = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
  $id = $t.id
  if ($id -notlike $Theme) { continue }

  # ---------------- SCSS ----------------
  $scss = New-Object System.Collections.Generic.List[string]
  $scss.Add("// $id - design tokens generated from themes/$id/tokens.json")
  $scss.Add("// regenerate: tools/export-tokens.ps1 -Theme $id")
  $scss.Add("")
  foreach ($mode in @("light", "dark")) {
    $m = $t.$mode
    if (-not $m) { continue }
    $scss.Add("// $mode mode")
    foreach ($k in $colorKeys) {
      $v = $m.colors.$k
      if ($v) { $scss.Add(('$' + $id + '-' + $mode + '-' + $k + ': ' + $v + ' !default;')) }
    }
    if ($m.shadows) {
      $scss.Add(('$' + $id + '-' + $mode + '-shadow-sm: ' + $m.shadows.sm + ' !default;'))
      $scss.Add(('$' + $id + '-' + $mode + '-shadow-md: ' + $m.shadows.md + ' !default;'))
      $scss.Add(('$' + $id + '-' + $mode + '-shadow-lg: ' + $m.shadows.lg + ' !default;'))
    }
    $scss.Add("")
  }
  $scss.Add("// static tokens")
  $scss.Add(('$' + $id + '-font-body: ' + $t.static.fonts.body + ' !default;'))
  $scss.Add(('$' + $id + '-font-display: ' + $t.static.fonts.display + ' !default;'))
  $scss.Add(('$' + $id + '-font-mono: ' + $t.static.fonts.mono + ' !default;'))
  [IO.File]::WriteAllText((Join-Path $scssDir ("_" + $id + ".scss")), ($scss -join "`n"), $utf8NoBom)

  # ---------------- Figma tokens ----------------
  $figma = New-Object PSObject
  foreach ($mode in @("light", "dark")) {
    if ($t.$mode) {
      $figma | Add-Member -NotePropertyName $mode -NotePropertyValue (New-FigmaColorSet $t.$mode.colors)
    }
  }
  $figmaJson = $figma | ConvertTo-Json -Depth 5
  [IO.File]::WriteAllText((Join-Path $figmaDir ($id + ".tokens.json")), $figmaJson, $utf8NoBom)

  # ---------------- JavaScript ----------------
  $jsProps = @{ name = $t.name; modes = $t.modes; static = $t.static }
  foreach ($mode in @("light", "dark")) {
    if ($t.$mode) { $jsProps[$mode] = $t.$mode }
  }
  $jsObj = [pscustomobject]$jsProps
  $jsJson = $jsObj | ConvertTo-Json -Depth 8
  $js = "// $id - design tokens generated from themes/$id/tokens.json`n" +
        "// regenerate: tools/export-tokens.ps1 -Theme $id`n`n" +
        "const theme = $jsJson;`n`nexport default theme;`n"
  [IO.File]::WriteAllText((Join-Path $jsDir ($id + ".js")), $js, $utf8NoBom)

  $exported++
  Write-Host "exported $id (scss, figma, js)"
}

Write-Host ""
Write-Host "Exported $exported theme(s) -> $OutDir"
if ($exported -eq 0) { Write-Warning "No themes matched -Theme '$Theme'" }
exit 0
