<#
.SYNOPSIS
  Auto-correct theme colors that fail WCAG contrast, with minimal visual shift.

.DESCRIPTION
  Companion to check-contrast.ps1. For every failing pair it blends the
  responsible token toward black (light mode) or white (dark mode) — the
  smallest shift that passes the threshold — and reports old -> new.

  Adjustable tokens: primary, secondary, accent, success, warning, error,
  info, textMuted. Backgrounds, text, surfaces and subtle tints are never
  touched. When a brand color moves, its *Hover is re-derived (12% further
  in the same direction) and re-checked. Because ring usually shares the
  primary hex, it follows automatically via the hex replacement.

  File patching (-Apply) is a plain hex replacement inside the theme's
  tokens.json and theme.css, so tokens, CSS variables (including the
  duplicated dark-mode blocks) and catalog swatches stay in sync.

.PARAMETER Level
  Target WCAG level: "aa" (default) or "aaa".

.PARAMETER Theme
  Only process themes whose id matches this wildcard.

.PARAMETER Apply
  Write corrected values into themes/<id>/tokens.json and theme.css.
  Without it the script only prints the plan.

.EXAMPLE
  powershell -File tools/fix-contrast.ps1                    # dry run, all themes, AA
  powershell -File tools/fix-contrast.ps1 -Apply             # apply AA fixes
  powershell -File tools/fix-contrast.ps1 -Level aaa -Theme high-contrast -Apply
#>
[CmdletBinding()]
param(
  [ValidateSet("aa", "aaa")]
  [string]$Level = "aa",
  [string]$Theme = "*",
  [switch]$Apply
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$themesDir = Join-Path $repoRoot "themes"
$required = if ($Level -eq "aaa") { 7.0 } else { 4.5 }

# --- color math -------------------------------------------------------------

function Get-Luminance {
  param([string]$Hex)
  $h = $Hex.TrimStart('#')
  if ($h.Length -eq 3) { $h = -join ($h.ToCharArray() | ForEach-Object { "$_$_" }) }
  $r = [Convert]::ToInt32($h.Substring(0, 2), 16) / 255.0
  $g = [Convert]::ToInt32($h.Substring(2, 2), 16) / 255.0
  $b = [Convert]::ToInt32($h.Substring(4, 2), 16) / 255.0
  $lin = { param($c) if ($c -le 0.03928) { $c / 12.92 } else { [math]::Pow((($c + 0.055) / 1.055), 2.4) } }
  return 0.2126 * (& $lin $r) + 0.7152 * (& $lin $g) + 0.0722 * (& $lin $b)
}

function Get-ContrastRatio {
  param([string]$A, [string]$B)
  $l1 = Get-Luminance $A; $l2 = Get-Luminance $B
  if ($l1 -lt $l2) { $t = $l1; $l1 = $l2; $l2 = $t }
  return ($l1 + 0.05) / ($l2 + 0.05)
}

function ConvertTo-Hex {
  param([double[]]$Rgb)
  return "#" + (($Rgb | ForEach-Object { "{0:x2}" -f [int][math]::Round($_) }) -join "")
}

function ConvertFrom-Hex {
  param([string]$Hex)
  $h = $Hex.TrimStart('#')
  if ($h.Length -eq 3) { $h = -join ($h.ToCharArray() | ForEach-Object { "$_$_" }) }
  return @([Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16))
}

# mix a toward target by t (0..1)
function Mix {
  param([string]$Hex, [double]$T, [int[]]$Target)
  $a = ConvertFrom-Hex $Hex
  $r = ($a[0] * (1 - $T)) + ($Target[0] * $T)
  $g = ($a[1] * (1 - $T)) + ($Target[1] * $T)
  $b = ($a[2] * (1 - $T)) + ($Target[2] * $T)
  return ConvertTo-Hex @($r, $g, $b)
}

# smallest blend of $Hex toward $Target that makes ratio($Hex', $Against) >= $Need
function Find-MinimalBlend {
  param([string]$Hex, [int[]]$Target, [string]$Against, [double]$Need)
  if ((Get-ContrastRatio $Hex $Against) -ge $Need) { return $Hex }
  $lo = 0.0; $hi = 1.0; $best = $null
  for ($i = 0; $i -lt 40; $i++) {
    $mid = ($lo + $hi) / 2
    $cand = Mix $Hex $mid $Target
    if ((Get-ContrastRatio $cand $Against) -ge $Need) { $best = $cand; $hi = $mid } else { $lo = $mid }
  }
  if (-not $best) { throw "Cannot reach ratio $Need for $Hex vs $Against" }
  return $best
}

# --- pairs: which token to adjust for each failing pair ----------------------

$pairs = @(
  @{ label = "text / bg";                fg = "text";      bg = "bg";             adjust = "text";      against = "bg" },
  @{ label = "text / surface";           fg = "text";      bg = "surface";        adjust = "text";      against = "bg" },
  @{ label = "text / surfaceRaised";     fg = "text";      bg = "surfaceRaised";  adjust = "text";      against = "bg" },
  @{ label = "textMuted / bg";           fg = "textMuted"; bg = "bg";             adjust = "textMuted"; against = "bg" },
  @{ label = "bg / primary";             fg = "bg";        bg = "primary";        adjust = "primary";   against = "fg" },
  @{ label = "bg / secondary";           fg = "bg";        bg = "secondary";      adjust = "secondary"; against = "fg" },
  @{ label = "bg / accent";              fg = "bg";        bg = "accent";         adjust = "accent";    against = "fg" },
  @{ label = "success / successSubtle";  fg = "success";   bg = "successSubtle";  adjust = "success";   against = "bg" },
  @{ label = "warning / warningSubtle";  fg = "warning";   bg = "warningSubtle";  adjust = "warning";   against = "bg" },
  @{ label = "error / errorSubtle";      fg = "error";     bg = "errorSubtle";    adjust = "error";     against = "bg" },
  @{ label = "info / infoSubtle";        fg = "info";      bg = "infoSubtle";     adjust = "info";      against = "bg" }
)

$brandTokens = @("primary", "secondary", "accent")

# --- compute plan ------------------------------------------------------------

$tokenFiles = Get-ChildItem -Path $themesDir -Directory | ForEach-Object {
  Join-Path $_.FullName "tokens.json"
} | Where-Object { Test-Path $_ } | Sort-Object

$plan = @{}   # themeId -> list of psobjects {mode, token, old, new}

foreach ($file in $tokenFiles) {
  $tokens = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
  $id = $tokens.id
  if ($id -notlike $Theme) { continue }

  foreach ($mode in @("light", "dark")) {
    $colors = $tokens.$mode.colors
    if (-not $colors) { continue }

    # blend target: dark-on-light vs light-on-dark
    $target = if ($mode -eq "light") { @(0, 0, 0) } else { @(255, 255, 255) }
    $adjusted = @{}

    foreach ($p in $pairs) {
      $fgHex = if ($adjusted.ContainsKey($p.fg)) { $adjusted[$p.fg] } else { $colors.($p.fg) }
      $bgHex = if ($adjusted.ContainsKey($p.bg)) { $adjusted[$p.bg] } else { $colors.($p.bg) }
      if (-not $fgHex -or -not $bgHex) { continue }

      if ((Get-ContrastRatio $fgHex $bgHex) -ge $required) { continue }
      if ($p.adjust -eq "text") {
        Write-Warning "$id/$mode : text pair failed but 'text' is not auto-adjusted - fix manually"
        continue
      }

      $againstSide = $p.against
      $againstHex = if ($adjusted.ContainsKey($p.$againstSide)) { $adjusted[$p.$againstSide] } else { $colors.($p.$againstSide) }

      $old = $colors.($p.adjust)
      $new = Find-MinimalBlend -Hex $old -Target $target -Against $againstHex -Need $required
      $adjusted[$p.adjust] = $new

      if (-not $plan[$id]) { $plan[$id] = New-Object System.Collections.Generic.List[object] }
      $plan[$id].Add([pscustomobject]@{ mode = $mode; token = $p.adjust; old = $old; new = $new; pair = $p.label; ratio = (Get-ContrastRatio $new $againstHex) })
    }

    # re-derive hover states for moved brand colors
    foreach ($b in $brandTokens) {
      if (-not $adjusted.ContainsKey($b)) { continue }
      $hoverKey = "${b}Hover"
      $oldHover = $colors.$hoverKey
      if (-not $oldHover) { continue }
      $newHover = Mix $adjusted[$b] 0.12 $target
      # hover must still pass the button contrast
      while ((Get-ContrastRatio $newHover $colors.bg) -lt $required) {
        $newHover = Mix $newHover 0.08 $target
      }
      if ($newHover -ne $oldHover) {
        $plan[$id].Add([pscustomobject]@{ mode = $mode; token = $hoverKey; old = $oldHover; new = $newHover; pair = "hover re-derived"; ratio = (Get-ContrastRatio $newHover $colors.bg) })
        $adjusted[$hoverKey] = $newHover
      }
    }
  }
}

# --- report ------------------------------------------------------------------

$total = 0
foreach ($id in $plan.Keys) {
  Write-Host ""
  Write-Host "$id" -ForegroundColor Cyan
  foreach ($c in ($plan[$id] | Sort-Object mode, token)) {
    $total++
    Write-Host ("  {5,-5} {0,-12} {1} -> {2}   ({3}, now {4:N2})" -f $c.token, $c.old, $c.new, $c.pair, $c.ratio, $c.mode)
  }
}

if ($total -eq 0) {
  Write-Host "Nothing to fix - all pairs already pass $Level.ToUpper()." -ForegroundColor Green
  exit 0
}

if (-not $Apply) {
  Write-Host ""
  Write-Host "Dry run: $total planned change(s). Re-run with -Apply to write them."
  exit 0
}

# --- apply: scoped patching of tokens.json, theme.css and catalog swatches ---

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$brandTokens = @("primary", "secondary", "accent")

foreach ($id in $plan.Keys) {
  $changes = $plan[$id]

  # tokens.json: scoped to the mode block and the token name
  $path = Join-Path $themesDir "$id/tokens.json"
  $content = [IO.File]::ReadAllText($path)
  foreach ($c in $changes) {
    $pattern = '"' + $c.mode + '"\s*:\s*\{\s*"colors"\s*:\s*\{[^{}]*?"' + $c.token + '"\s*:\s*"' + $c.old + '"'
    $before = $content
    $content = [regex]::Replace($content, $pattern, { param($m) $m.Value -replace [regex]::Escape($c.old), $c.new })
    if ($content -eq $before) {
      Write-Warning "tokens.json/$id : pattern not matched for $($c.mode) $($c.token) $($c.old)"
    }
  }
  [IO.File]::WriteAllText($path, $content, $utf8NoBom)

  # theme.css: kebab-case var names; dark values intentionally occur twice
  # (explicit data-mode block + prefers-color-scheme block) - replace all
  $cssPath = Join-Path $themesDir "$id/theme.css"
  $css = [IO.File]::ReadAllText($cssPath)
  foreach ($c in $changes) {
    $var = ($c.token -creplace '([A-Z])', '-$1').ToLower()
    $pattern = '(--' + $var + '\s*:\s*)' + $c.old + '\b'
    $css = [regex]::Replace($css, $pattern, { param($m) $m.Groups[1].Value + $c.new })
  }
  [IO.File]::WriteAllText($cssPath, $css, $utf8NoBom)

  # catalog swatches: only light-mode brand colors are displayed there
  $swatchChanges = @($changes | Where-Object { $_.mode -eq "light" -and $brandTokens -ccontains $_.token })
  if ($swatchChanges.Count -gt 0) {
    foreach ($rel in @("themes.json", "preview.html")) {
      $p2 = Join-Path $themesDir $rel
      $c2 = [IO.File]::ReadAllText($p2)
      foreach ($c in $swatchChanges) { $c2 = $c2.Replace($c.old, $c.new) }
      [IO.File]::WriteAllText($p2, $c2, $utf8NoBom)
    }
  }

  Write-Host "patched $id (tokens.json, theme.css$(if ($swatchChanges.Count -gt 0) { ', catalog swatches' }))"
}

Write-Host ""
Write-Host "Applied $total change(s). Re-run tools/check-contrast.ps1 to verify."
exit 0
