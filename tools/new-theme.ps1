<#
.SYNOPSIS
  Scaffold a new design-assets theme (tokens.json + theme.css + tailwind.css).

.DESCRIPTION
  Derives a complete token set from a small palette:

    -BgLight / -BgDark            page backgrounds
    -Primary/-Secondary/-Accent   light-mode brand colors
    -PrimaryDark/...              optional dark-mode brands (default: lightened)

  Surfaces, borders, text tones, hover states and *Subtle tints are derived
  by blending; every text-bearing pair is then contrast-corrected (same math
  as tools/check-contrast.ps1) so generated themes pass WCAG AA by
  construction.

  By default the theme is also registered in themes/themes.json,
  themes/preview.html and README.md (use -NoRegister to skip).

.PARAMETER Radius
  Radius personality: soft | medium | sharp.

.PARAMETER Display
  Display font personality: serif | rounded | mono | sans.

.EXAMPLE
  powershell -File tools/new-theme.ps1 -Id sakura -Name Sakura `
    -Description "Soft cherry-blossom pinks with a deep plum night mode." `
    -Tags pastel,pink,spring -BgLight "#fff7f9" -BgDark "#241a1f" `
    -Primary "#c2557f" -Secondary "#8f6aa8" -Accent "#d98a6a" `
    -Radius soft -Display rounded
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Id,
  [Parameter(Mandatory)][string]$Name,
  [Parameter(Mandatory)][string]$Description,
  [string[]]$Tags = @(),
  [Parameter(Mandatory)][string]$BgLight,
  [Parameter(Mandatory)][string]$BgDark,
  [Parameter(Mandatory)][string]$Primary,
  [Parameter(Mandatory)][string]$Secondary,
  [Parameter(Mandatory)][string]$Accent,
  [string]$PrimaryDark = "",
  [string]$SecondaryDark = "",
  [string]$AccentDark = "",
  [switch]$DarkOnly,
  [ValidateSet("soft", "medium", "sharp")][string]$Radius = "medium",
  [ValidateSet("serif", "rounded", "mono", "sans")][string]$Display = "sans",
  [switch]$NoRegister,
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$themesDir = Join-Path $repoRoot "themes"
$themeDir = Join-Path $themesDir $Id

if ((Test-Path $themeDir) -and -not $Force) { throw "$themeDir already exists (use -Force to overwrite)" }
if ($Id -notmatch '^[a-z0-9-]+$') { throw "Id must be kebab-case" }

# allow -Tags pastel,pink,spring (single token) as well as -Tags pastel,pink,spring (array)
$Tags = @($Tags | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# --- color math (same conventions as check-contrast / fix-contrast) ---------

$BLACK = @(0, 0, 0); $WHITE = @(255, 255, 255)

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

function ConvertFrom-Hex {
  param([string]$Hex)
  $h = $Hex.TrimStart('#')
  if ($h.Length -eq 3) { $h = -join ($h.ToCharArray() | ForEach-Object { "$_$_" }) }
  return @([Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16))
}

function ConvertTo-Hex {
  param([double[]]$Rgb)
  return "#" + (($Rgb | ForEach-Object { "{0:x2}" -f [int][math]::Round([math]::Min(255, [math]::Max(0, $_))) }) -join "")
}

function Mix {
  param([string]$Hex, [double]$T, $Target)
  if ($Target -is [string]) { $Target = ConvertFrom-Hex $Target }
  $rgb = [int[]]$Target
  $a = ConvertFrom-Hex $Hex
  $r = ($a[0] * (1 - $T)) + ($rgb[0] * $T)
  $g = ($a[1] * (1 - $T)) + ($rgb[1] * $T)
  $b = ($a[2] * (1 - $T)) + ($rgb[2] * $T)
  return ConvertTo-Hex @($r, $g, $b)
}

# smallest blend toward target so ratio(hex', against) >= need
function Approve {
  param([string]$Hex, [string]$Against, [double]$Need, $Target)
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

# --- personalities -----------------------------------------------------------

$radiusSets = @{
  soft   = @{ sm = "0.3125"; md = "0.5625"; lg = "0.8125"; xl = "1.125" }
  medium = @{ sm = "0.25";   md = "0.5";    lg = "0.75";   xl = "1.0" }
  sharp  = @{ sm = "0.125";  md = "0.1875"; lg = "0.25";   xl = "0.375" }
}
$displayFonts = @{
  serif   = 'Georgia, "Palatino Linotype", "Book Antiqua", serif'
  rounded = 'ui-rounded, "Hiragino Maru Gothic ProN", Quicksand, Comfortaa, "Segoe UI", sans-serif'
  mono    = 'ui-monospace, "Cascadia Code", "SF Mono", Menlo, Consolas, monospace'
  sans    = '"Segoe UI", -apple-system, BlinkMacSystemFont, Roboto, sans-serif'
}
$bodyFont = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif'
$monoFont = 'ui-monospace, "Cascadia Code", "SF Mono", Menlo, Consolas, monospace'
$r = $radiusSets[$Radius]

# --- derive palettes ---------------------------------------------------------

function New-ModePalette {
  param([bool]$IsDark, [string]$Bg, [hashtable]$BrandIn)

  $dir = $BLACK; if ($IsDark) { $dir = $WHITE }

  $surfaceT = 0.045;  if ($IsDark) { $surfaceT = 0.05 }
  $raisedT  = 0.55;   if ($IsDark) { $raisedT  = 0.12 }
  $borderT  = 0.11;   if ($IsDark) { $borderT  = 0.19 }
  $textT    = 0.84;   if ($IsDark) { $textT    = 0.93 }
  $mutedT   = 0.52;   if ($IsDark) { $mutedT   = 0.60 }
  $subtleT  = 0.84;   if ($IsDark) { $subtleT  = 0.78 }
  $brandSubtleT = 0.84; if ($IsDark) { $brandSubtleT = 0.80 }

  $p = @{}
  $p.bg            = $Bg
  $p.surface       = Mix $Bg $surfaceT $dir
  $p.surfaceRaised = Mix $Bg $raisedT $WHITE
  $p.border        = Mix $Bg $borderT $dir
  $p.text          = Approve (Mix $Bg $textT $dir)  $Bg 7.0 $dir
  $p.textMuted     = Approve (Mix $Bg $mutedT $dir) $Bg 4.5 $dir

  # brands: correct against bg (filled buttons use bg as label color)
  foreach ($k in @("primary", "secondary", "accent")) {
    $base = $BrandIn[$k]
    if ($IsDark) {
      $dk = $BrandIn[$k + "Dark"]
      if ($dk) { $base = $dk } else { $base = Mix $BrandIn[$k] 0.35 $WHITE }
    }
    $approved = Approve $base $Bg 4.5 $dir
    $p[$k] = $approved
    $p[$k + "Hover"] = Approve (Mix $approved 0.12 $dir) $Bg 4.5 $dir
    $p[$k + "Subtle"] = Mix $approved $brandSubtleT $Bg
  }

  # status colors vs their subtle tints
  $status = @{
    success = "#3e7d54"; warning = "#9a7b16"; error = "#bb4a44"; info = "#3f6f9f"
  }
  if ($IsDark) {
    $status = @{ success = "#7fbf94"; warning = "#d9b25e"; error = "#e08080"; info = "#80aad9" }
  }
  foreach ($k in @("success", "warning", "error", "info")) {
    $subtle = Mix $status[$k] $subtleT $Bg
    $p[$k + "Subtle"] = $subtle
    $p[$k] = Approve $status[$k] $subtle 4.5 $dir
  }

  $p.ring = $p.primary
  if ($IsDark) {
    $p.shadowSm = "0 1px 2px rgba(0, 0, 0, 0.35)"
    $p.shadowMd = "0 4px 16px rgba(0, 0, 0, 0.42)"
    $p.shadowLg = "0 16px 44px rgba(0, 0, 0, 0.52)"
  } else {
    $rgb = (ConvertFrom-Hex $p.text | ForEach-Object { [int]$_ }) -join ", "
    $p.shadowSm = "0 1px 2px rgba($rgb, 0.08)"
    $p.shadowMd = "0 4px 14px rgba($rgb, 0.10)"
    $p.shadowLg = "0 14px 36px rgba($rgb, 0.16)"
  }
  return $p
}

$brandIn = @{
  primary = $Primary; secondary = $Secondary; accent = $Accent
  primaryDark = $PrimaryDark; secondaryDark = $SecondaryDark; accentDark = $AccentDark
}

$light = $null
if (-not $DarkOnly) { $light = New-ModePalette -IsDark $false -Bg $BgLight -BrandIn $brandIn }
$dark = New-ModePalette -IsDark $true -Bg $BgDark -BrandIn $brandIn
$modes = @("dark"); if (-not $DarkOnly) { $modes = @("light", "dark") }

# --- shared fragments ---------------------------------------------------------

function New-ColorsJson {
  param([hashtable]$P)
  $order = @("bg", "surface", "surfaceRaised", "border", "text", "textMuted", "ring",
             "primary", "primaryHover", "primarySubtle",
             "secondary", "secondaryHover", "secondarySubtle",
             "accent", "accentHover", "accentSubtle",
             "success", "successSubtle", "warning", "warningSubtle",
             "error", "errorSubtle", "info", "infoSubtle")
  return ((@($order | ForEach-Object { '      "{0}": "{1}"' -f $_, $P[$_] }) -join ",`n"))
}

function New-ShadowsJson {
  param([hashtable]$P)
  $nl = "`n      "
  return '      "sm": "' + $P.shadowSm + '",' + $nl + '"md": "' + $P.shadowMd + '",' + $nl + '"lg": "' + $P.shadowLg + '"'
}

function New-CssVars {
  param([hashtable]$P, [string]$Indent)
  $map = [ordered]@{
    bg = "bg"; surface = "surface"; surfaceRaised = "surface-raised"; border = "border"
    text = "text"; textMuted = "text-muted"; ring = "ring"
    primary = "primary"; primaryHover = "primary-hover"; primarySubtle = "primary-subtle"
    secondary = "secondary"; secondaryHover = "secondary-hover"; secondarySubtle = "secondary-subtle"
    accent = "accent"; accentHover = "accent-hover"; accentSubtle = "accent-subtle"
    success = "success"; successSubtle = "success-subtle"
    warning = "warning"; warningSubtle = "warning-subtle"
    error = "error"; errorSubtle = "error-subtle"
    info = "info"; infoSubtle = "info-subtle"
  }
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($k in $map.Keys) { $out.Add(("{0}--{1}: {2};" -f $Indent, $map[$k], $P[$k])) }
  $out.Add("")
  $out.Add(("{0}--shadow-sm: {1};" -f $Indent, $P.shadowSm))
  $out.Add(("{0}--shadow-md: {1};" -f $Indent, $P.shadowMd))
  $out.Add(("{0}--shadow-lg: {1};" -f $Indent, $P.shadowLg))
  return ($out -join "`n")
}

# swatch follows catalog convention: [darkBg, lightPrimary, darkPrimary|lightSecondary, accent, lightBg]
if ($DarkOnly) {
  $swatch = @($BgDark, $dark.primary, $dark.secondary, $dark.accent, $dark.surfaceRaised)
} else {
  $third = $light.secondary; if ($PrimaryDark) { $third = $PrimaryDark }
  $swatch = @($BgDark, $light.primary, $third, $light.accent, $BgLight)
}
$swatchJson = (@($swatch | ForEach-Object { '"' + $_ + '"' }) -join ", ")
$tagsJson = (@($Tags | ForEach-Object { '"' + $_ + '"' }) -join ", ")
$modesJson = (@($modes | ForEach-Object { '"' + $_ + '"' }) -join ", ")
$bodyFontJson = $bodyFont -replace '"', '\"'
$displayFontJson = $displayFonts[$Display] -replace '"', '\"'
$monoFontJson = $monoFont -replace '"', '\"'
$descJson = $Description -replace '"', '\"'

# --- emit tokens.json ---------------------------------------------------------

$tokensJson = @'
{
  "id": "__ID__",
  "name": "__NAME__",
  "description": "__DESC__",
  "tags": [__TAGS__],
  "modes": [__MODES__],
  "files": {
    "css": "__ID__/theme.css",
    "tokens": "__ID__/tokens.json",
    "tailwind": "__ID__/tailwind.css"
  },
  "swatch": [__SWATCH__],
  "static": {
    "fonts": {
      "body": "__BODYFONT__",
      "display": "__DISPLAYFONT__",
      "mono": "__MONOFONT__"
    },
    "typeScale": {
      "xs": 0.75,
      "sm": 0.875,
      "base": 1.0,
      "lg": 1.125,
      "xl": 1.25,
      "2xl": 1.5,
      "3xl": 1.875,
      "4xl": 2.25
    },
    "weights": { "normal": 400, "medium": 500, "semibold": 600, "bold": 700 },
    "spacingBase": 0.25,
    "radius": { "sm": __RSM__, "md": __RMD__, "lg": __RLG__, "xl": __RXL__, "full": 9999 }
  },
__MODEBLOCKS__
}
'@

$modeBlocks = New-Object System.Collections.Generic.List[string]
if ($light) {
  $modeBlocks.Add(@'
  "light": {
    "colors": {
__COLORS__
    },
    "shadows": {
__SHADOWS__
    }
  }
'@.Replace("__COLORS__", (New-ColorsJson $light)).Replace("__SHADOWS__", (New-ShadowsJson $light)))
}
$modeBlocks.Add(@'
  "dark": {
    "colors": {
__COLORS__
    },
    "shadows": {
__SHADOWS__
    }
  }
'@.Replace("__COLORS__", (New-ColorsJson $dark)).Replace("__SHADOWS__", (New-ShadowsJson $dark)))

$tokensJson = $tokensJson.
  Replace("__ID__", $Id).
  Replace("__NAME__", $Name).
  Replace("__DESC__", $descJson).
  Replace("__TAGS__", $tagsJson).
  Replace("__MODES__", $modesJson).
  Replace("__SWATCH__", $swatchJson).
  Replace("__BODYFONT__", $bodyFontJson).
  Replace("__DISPLAYFONT__", $displayFontJson).
  Replace("__MONOFONT__", $monoFontJson).
  Replace("__RSM__", $r.sm).Replace("__RMD__", $r.md).
  Replace("__RLG__", $r.lg).Replace("__RXL__", $r.xl).
  Replace("__MODEBLOCKS__", ($modeBlocks -join ",`n"))

# --- emit theme.css -----------------------------------------------------------

$descShort = ($Description -split " -- ")[0]
$modeNote = "Mode:  follows OS preference by default; force with data-mode=`"light`""
if ($DarkOnly) { $modeNote = "Mode:  dark-only - this theme intentionally ignores light/dark toggles." }

$header = @'
/* ==========================================================================
   __NAME__ - __DESCSHORT__
   Usage: set data-theme="__ID__" on <html>, <body> or any container.
   __MODENOTE__
   ========================================================================== */

:root {
  /* Typography */
  --font-body: __BODYFONT__;
  --font-display: __DISPLAYFONT__;
  --font-mono: __MONOFONT__;

  --text-xs: 0.75rem;        --text-xs--line-height: 1.3333;
  --text-sm: 0.875rem;       --text-sm--line-height: 1.4286;
  --text-base: 1rem;         --text-base--line-height: 1.5;
  --text-lg: 1.125rem;       --text-lg--line-height: 1.5556;
  --text-xl: 1.25rem;        --text-xl--line-height: 1.4;
  --text-2xl: 1.5rem;        --text-2xl--line-height: 1.3333;
  --text-3xl: 1.875rem;      --text-3xl--line-height: 1.2;
  --text-4xl: 2.25rem;       --text-4xl--line-height: 1.1111;

  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;

  /* Spacing scale */
  --spacing: 0.25rem;

  /* Radius personality: __RADIUS__ */
  --radius-sm: __RSM__rem;
  --radius-md: __RMD__rem;
  --radius-lg: __RLG__rem;
  --radius-xl: __RXL__rem;
  --radius-full: 9999px;
}
'@
$header = $header.
  Replace("__NAME__", $Name).
  Replace("__DESCSHORT__", $descShort).
  Replace("__ID__", $Id).
  Replace("__MODENOTE__", $modeNote).
  Replace("__BODYFONT__", $bodyFont).
  Replace("__DISPLAYFONT__", $displayFonts[$Display]).
  Replace("__MONOFONT__", $monoFont).
  Replace("__RADIUS__", $Radius).
  Replace("__RSM__", $r.sm).Replace("__RMD__", $r.md).
  Replace("__RLG__", $r.lg).Replace("__RXL__", $r.xl)

$sections = New-Object System.Collections.Generic.List[string]

if ($light) {
  $sections.Add(@'
/* --------------------------------------------------------------------------
   Light mode
   -------------------------------------------------------------------------- */
[data-theme="__ID__"] {
  color-scheme: light;

__VARS__
}
'@.Replace("__ID__", $Id).Replace("__VARS__", (New-CssVars $light "  ")))
}

if ($DarkOnly) {
  $sections.Add(@'
/* --------------------------------------------------------------------------
   Dark-only palette
   -------------------------------------------------------------------------- */
[data-theme="__ID__"] {
  color-scheme: dark;

__VARS__
}
'@.Replace("__ID__", $Id).Replace("__VARS__", (New-CssVars $dark "  ")))
} else {
  $sections.Add(@'
/* --------------------------------------------------------------------------
   Dark mode - explicit override via attribute or class
   -------------------------------------------------------------------------- */
[data-theme="__ID__"][data-mode="dark"],
.dark [data-theme="__ID__"]:not([data-mode="light"]) {
  color-scheme: dark;

__VARS__
}
'@.Replace("__ID__", $Id).Replace("__VARS__", (New-CssVars $dark "  ")))

  $sections.Add(@'
/* --------------------------------------------------------------------------
   Dark mode - automatic fallback to OS preference
   -------------------------------------------------------------------------- */
@media (prefers-color-scheme: dark) {
  [data-theme="__ID__"]:not([data-mode="light"]) {
    color-scheme: dark;

__VARS__
  }
}
'@.Replace("__ID__", $Id).Replace("__VARS__", (New-CssVars $dark "    ")))
}

$themeCss = $header + "`n`n" + (($sections -join "`n`n")) + "`n"

# --- emit tailwind.css --------------------------------------------------------

$tailNote = ""
if ($DarkOnly) { $tailNote = "   Dark-only: the theme has no light mode by design." }

$tailwindCss = @'
/* ==========================================================================
   __NAME__ - Tailwind CSS v4 theme mapping
   Requires: __ID__/theme.css (provides the runtime variables below).
   Import AFTER `@import "tailwindcss";` in your main stylesheet.

     @import "tailwindcss";
     @import "../../themes/__ID__/theme.css";
     @import "../../themes/__ID__/tailwind.css";

   Set data-theme="__ID__" on <html> (or a container) to activate.
__TAILNOTE__
   ========================================================================== */

@theme inline {
  /* Surfaces & text */
  --color-bg: var(--bg);
  --color-surface: var(--surface);
  --color-raised: var(--surface-raised);
  --color-line: var(--border);
  --color-fg: var(--text);
  --color-muted-fg: var(--text-muted);

  /* Brand */
  --color-primary: var(--primary);
  --color-primary-hover: var(--primary-hover);
  --color-primary-subtle: var(--primary-subtle);
  --color-secondary: var(--secondary);
  --color-secondary-hover: var(--secondary-hover);
  --color-secondary-subtle: var(--secondary-subtle);
  --color-accent: var(--accent);
  --color-accent-hover: var(--accent-hover);
  --color-accent-subtle: var(--accent-subtle);

  /* Status */
  --color-success: var(--success);
  --color-success-subtle: var(--success-subtle);
  --color-warning: var(--warning);
  --color-warning-subtle: var(--warning-subtle);
  --color-error: var(--error);
  --color-error-subtle: var(--error-subtle);
  --color-info: var(--info);
  --color-info-subtle: var(--info-subtle);

  /* Focus */
  --color-ring: var(--ring);

  /* Typography */
  --font-sans: var(--font-body);
  --font-display: var(--font-display);
  --font-mono: var(--font-mono);

  --text-xs: var(--text-xs);
  --text-sm: var(--text-sm);
  --text-base: var(--text-base);
  --text-lg: var(--text-lg);
  --text-xl: var(--text-xl);
  --text-2xl: var(--text-2xl);
  --text-3xl: var(--text-3xl);
  --text-4xl: var(--text-4xl);

  /* Radius personality */
  --radius-sm: var(--radius-sm);
  --radius-md: var(--radius-md);
  --radius-lg: var(--radius-lg);
  --radius-xl: var(--radius-xl);

  /* Shadows */
  --shadow-sm: var(--shadow-sm);
  --shadow-md: var(--shadow-md);
  --shadow-lg: var(--shadow-lg);

  /* Spacing scale base (enables p-4, gap-2, etc.) */
  --spacing: var(--spacing);
}
'@.Replace("__NAME__", $Name).Replace("__ID__", $Id).Replace("__TAILNOTE__", $tailNote)

# --- write files --------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $themeDir | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $themeDir "tokens.json"), $tokensJson, $utf8NoBom)
[IO.File]::WriteAllText((Join-Path $themeDir "theme.css"), $themeCss, $utf8NoBom)
[IO.File]::WriteAllText((Join-Path $themeDir "tailwind.css"), $tailwindCss, $utf8NoBom)

# sanity: tokens must parse
Get-Content (Join-Path $themeDir "tokens.json") -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
Write-Host "created $Id (tokens.json, theme.css, tailwind.css)"

# --- registration ---------------------------------------------------------------

if (-not $NoRegister) {
  # NB: parentheses are required - inside @(), a trailing comma binds tighter
  # than '+' and would split each concatenation into separate elements
  $entryLines = @(
    ('    {'),
    ('      "id": "' + $Id + '",'),
    ('      "displayName": "' + $Name + '",'),
    ('      "description": "' + $Description + '",'),
    ('      "tags": [' + $tagsJson + '],'),
    ('      "modes": [' + $modesJson + '],'),
    ('      "files": {'),
    ('        "css": "' + $Id + '/theme.css",'),
    ('        "tokens": "' + $Id + '/tokens.json",'),
    ('        "tailwind": "' + $Id + '/tailwind.css"'),
    ('      },'),
    ('      "swatch": [' + $swatchJson + ']'),
    ('    }')
  )
  $entry = ($entryLines -join "`n")

  # themes.json: insert before closing "  ]\n}"
  $cat = Join-Path $themesDir "themes.json"
  $c = [IO.File]::ReadAllText($cat)
  if ($c -notmatch [regex]::Escape('"id": "' + $Id + '"')) {
    $pattern = '\}\s*\n  \]\s*\}\s*$'
    $replacement = "},`n" + $entry + "`n  ]`n}"
    $new = [regex]::Replace($c, $pattern, { param($m) $replacement })
    if ($new -eq $c) { Write-Warning "themes.json: insertion point not found" }
    [IO.File]::WriteAllText($cat, $new, $utf8NoBom)
    Write-Host "registered in themes.json"
  }

  # preview.html: stylesheet link + card entry
  $prev = Join-Path $themesDir "preview.html"
  $h = [IO.File]::ReadAllText($prev)
  if ($h -notmatch [regex]::Escape('href="' + $Id + '/theme.css"')) {
    $linkPattern = '(<link rel="stylesheet" href="[a-z0-9-]+/theme\.css">)(\s*\n)(?=<style>)'
    $h = [regex]::Replace($h, $linkPattern, { param($m) $m.Groups[1].Value + "`n" + ('<link rel="stylesheet" href="' + $Id + '/theme.css">') + $m.Groups[2].Value })
    $swJs = (@($swatch | ForEach-Object { '"' + $_ + '"' }) -join ", ")
    $descJs = $descShort.Replace("'", "\'")
    $card = '    { id: "' + $Id + '", name: "' + $Name + '", desc: "' + $descJs + '",' + "`n" +
            '      swatch: [' + $swJs + '] },' + "`n" + '  ];'
    $h2 = [regex]::Replace($h, '  \];', { param($m) $card })
    if ($h2 -eq $h) { Write-Warning "preview.html: THEMES array not found" }
    [IO.File]::WriteAllText($prev, $h2, $utf8NoBom)
    Write-Host "registered in preview.html"
  }

  # README: bump count, add table row after the last existing row
  $readme = Join-Path $repoRoot "README.md"
  $md = [IO.File]::ReadAllText($readme)
  $count = ((Get-Content (Join-Path $themesDir "themes.json") -Raw -Encoding UTF8 | ConvertFrom-Json).themes).Count
  $md = [regex]::Replace($md, '\d+ pre-built UI themes', ("$count pre-built UI themes"))
  if ($md -notmatch [regex]::Escape("| $Name ")) {
    $vibe = $Description
    if ($vibe.Length -gt 45) { $vibe = $vibe.Substring(0, 45).TrimEnd() + "..." }
    $row = "| $Name | $vibe |"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.AddRange(($md -split "`r?`n"))
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\| ') { $idx = $i } }
    if ($idx -ge 0) { $lines.Insert($idx + 1, $row) } else { Write-Warning "README: table not found" }
    [IO.File]::WriteAllText($readme, (($lines -join "`n")), $utf8NoBom)
    Write-Host "registered in README.md (now $count themes)"
  }
}

Write-Host ""
Write-Host "Next: run tools/check-contrast.ps1 -Theme $Id and regenerate screenshots"
