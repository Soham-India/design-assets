<#
.SYNOPSIS
  WCAG 2.x color-contrast checker for design-assets themes.

.DESCRIPTION
  Reads every themes/<id>/tokens.json, computes WCAG 2.x contrast ratios for
  the color pairs that matter in real UI (body text, muted text, filled
  buttons, status chips) and reports AA/AAA pass/fail per pair per mode.

  Pairs checked (per mode):
    - text / bg             body copy              (AA 4.5, AAA 7.0)
    - text / surface        text on surfaces       (AA 4.5)
    - text / surfaceRaised  text on raised panels  (AA 4.5)
    - textMuted / bg        secondary copy         (AA 4.5)
    - bg / primary          label on primary btn   (AA 4.5)
    - bg / secondary        label on secondary btn (AA 4.5)
    - bg / accent           label on accent btn    (AA 4.5)
    - success|warning|error|info vs their *Subtle   chip text on chip bg (AA 4.5)

.PARAMETER Level
  Required WCAG level: "aa" (default) or "aaa".

.PARAMETER Theme
  Only check themes whose id matches this wildcard pattern (e.g. -Theme dusk).

.EXAMPLE
  powershell -File tools/check-contrast.ps1
  powershell -File tools/check-contrast.ps1 -Level aaa -Theme high-contrast

.NOTES
  Exit code 0 = all required pairs pass, 1 = at least one failure.
#>
[CmdletBinding()]
param(
  [ValidateSet("aa", "aaa")]
  [string]$Level = "aa",
  [string]$Theme = "*"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$themesDir = Join-Path $repoRoot "themes"

# --- WCAG 2.x relative luminance / contrast ratio --------------------------

function Get-Luminance {
  param([string]$Hex)

  $h = $Hex.TrimStart('#')
  if ($h.Length -eq 3) {
    $h = -join ($h.ToCharArray() | ForEach-Object { "$_$_" })
  }
  if ($h -notmatch '^[0-9a-fA-F]{6}$') { throw "Bad hex color: '$Hex'" }

  $r = [Convert]::ToInt32($h.Substring(0, 2), 16) / 255.0
  $g = [Convert]::ToInt32($h.Substring(2, 2), 16) / 255.0
  $b = [Convert]::ToInt32($h.Substring(4, 2), 16) / 255.0

  $lin = {
    param($c)
    if ($c -le 0.03928) { $c / 12.92 } else { [math]::Pow((($c + 0.055) / 1.055), 2.4) }
  }

  return 0.2126 * (& $lin $r) + 0.7152 * (& $lin $g) + 0.0722 * (& $lin $b)
}

function Get-ContrastRatio {
  param([string]$Fg, [string]$Bg)

  $l1 = Get-Luminance $Fg
  $l2 = Get-Luminance $Bg
  if ($l1 -lt $l2) { $tmp = $l1; $l1 = $l2; $l2 = $tmp }
  return ($l1 + 0.05) / ($l2 + 0.05)
}

# --- Pairs to evaluate ------------------------------------------------------

# label = display name, fg/bg = token names inside mode.colors
$pairs = @(
  @{ label = "text / bg";              fg = "text";      bg = "bg" },
  @{ label = "text / surface";         fg = "text";      bg = "surface" },
  @{ label = "text / surfaceRaised";   fg = "text";      bg = "surfaceRaised" },
  @{ label = "textMuted / bg";         fg = "textMuted"; bg = "bg" },
  @{ label = "bg / primary";           fg = "bg";        bg = "primary" },
  @{ label = "bg / secondary";         fg = "bg";        bg = "secondary" },
  @{ label = "bg / accent";            fg = "bg";        bg = "accent" },
  @{ label = "success / successSubtle";   fg = "success"; bg = "successSubtle" },
  @{ label = "warning / warningSubtle";   fg = "warning"; bg = "warningSubtle" },
  @{ label = "error / errorSubtle";       fg = "error";   bg = "errorSubtle" },
  @{ label = "info / infoSubtle";         fg = "info";    bg = "infoSubtle" }
)

$aaThreshold = 4.5
$aaaThreshold = 7.0
$required = if ($Level -eq "aaa") { $aaaThreshold } else { $aaThreshold }

# --- Run --------------------------------------------------------------------

$tokenFiles = Get-ChildItem -Path $themesDir -Directory | ForEach-Object {
  Join-Path $_.FullName "tokens.json"
} | Where-Object { Test-Path $_ } | Sort-Object

if (-not $tokenFiles) {
  Write-Error "No tokens.json found under $themesDir"
  exit 1
}

$global:pass = 0
$global:fail = 0
$failures = New-Object System.Collections.Generic.List[string]

foreach ($file in $tokenFiles) {
  $tokens = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
  $id = $tokens.id

  if ($id -notlike $Theme) { continue }

  foreach ($mode in @("light", "dark")) {
    $colors = $tokens.$mode.colors
    if (-not $colors) { continue }

    Write-Host ""
    Write-Host "$id ($mode)" -ForegroundColor Cyan

    foreach ($p in $pairs) {
      $fgToken = $colors.($p.fg)
      $bgToken = $colors.($p.bg)
      if (-not $fgToken -or -not $bgToken) { continue }

      $ratio = Get-ContrastRatio $fgToken $bgToken
      $ratioText = ("{0,5:N2}" -f $ratio)

      if ($ratio -ge $required) {
        $global:pass++
        Write-Host "  PASS $ratioText  $($p.label)" -ForegroundColor Green
      }
      else {
        $global:fail++
        $msg = "$id/$mode : $($p.label) = $ratioText (needs $required)"
        $failures.Add($msg)
        Write-Host "  FAIL $ratioText  $($p.label)  <- needs $required" -ForegroundColor Red
      }
    }
  }
}

Write-Host ""
Write-Host ("Level checked : {0}  (AA = {1}, AAA = {2})" -f $Level.ToUpper(), $aaThreshold, $aaaThreshold)
Write-Host ("Pairs passed  : {0}" -f $global:pass)
Write-Host ("Pairs failed  : {0}" -f $global:fail)

if ($failures.Count -gt 0) {
  Write-Host ""
  Write-Host "Failed pairs:" -ForegroundColor Yellow
  foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Yellow }
  exit 1
}
exit 0
