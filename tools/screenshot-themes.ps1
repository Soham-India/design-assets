<#
.SYNOPSIS
  Headless-browser screenshot generator for design-assets themes.

.DESCRIPTION
  Produces PNG previews for every theme listed in themes/themes.json:

    themes/screenshots/<id>-light.png   single-theme card, light mode
    themes/screenshots/<id>-dark.png    single-theme card, dark mode
    themes/screenshots/gallery-light.png  full preview.html gallery, light
    themes/screenshots/gallery-dark.png   full preview.html gallery, dark

  Dark-only themes (see "modes" in tokens.json) get a dark card only.
  Per-theme cards are rendered from a generated single-card page that uses
  the same card markup/styles as themes/preview.html — keep the two in sync.

  Requires Chrome or Edge; auto-detected, or force with -Browser.

.PARAMETER Browser
  "auto" (default), "chrome" or "edge".

.PARAMETER OutDir
  Output directory. Default: <repo>/themes/screenshots.

.PARAMETER Width / Height
  Viewport for single-theme cards. Default 560x900.

.PARAMETER GalleryOnly / CardsOnly
  Restrict what gets generated.

.EXAMPLE
  powershell -File tools/screenshot-themes.ps1
  powershell -File tools/screenshot-themes.ps1 -Browser edge -GalleryOnly
#>
[CmdletBinding()]
param(
  [ValidateSet("auto", "chrome", "edge")]
  [string]$Browser = "auto",
  [string]$OutDir = "",
  [int]$Width = 560,
  [int]$Height = 900,
  [switch]$GalleryOnly,
  [switch]$CardsOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$themesDir = Join-Path $repoRoot "themes"
if (-not $OutDir) { $OutDir = Join-Path $themesDir "screenshots" }

# --- locate a browser -------------------------------------------------------

$candidates = @(
  "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
)
$exe = switch ($Browser) {
  "chrome" { $candidates | Where-Object { $_ -like "*chrome*" } | Select-Object -First 1 }
  "edge"   { $candidates | Where-Object { $_ -like "*msedge*" } | Select-Object -First 1 }
  default  { $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1 }
}
if (-not $exe -or -not (Test-Path $exe)) {
  throw "No Chrome/Edge found. Install one or pass -Browser with a valid install."
}
Write-Host "Browser: $exe"

# --- helpers ----------------------------------------------------------------

function Invoke-HeadlessShot {
  param([string]$HtmlPath, [string]$PngPath, [string]$Size)

  if (Test-Path $PngPath) { Remove-Item $PngPath -Force }
  $url = "file:///$($HtmlPath -replace '\\', '/')"

  # chrome prints progress to stderr; merge into stdout so EAP=Stop doesn't throw
  $null = & $exe --headless=new --disable-gpu --hide-scrollbars `
    --force-device-scale-factor=1 --window-size=$Size `
    --screenshot="$PngPath" $url 2>&1

  # chrome may detach; poll briefly for the file
  $deadline = (Get-Date).AddSeconds(20)
  while ((Get-Date) -lt $deadline) {
    if ((Test-Path $PngPath) -and (Get-Item $PngPath).Length -gt 0) { return $true }
    Start-Sleep -Milliseconds 250
  }
  return $false
}

function New-CardHtml {
  param([object]$Theme, [ValidateSet("light", "dark")][string]$Mode)

  $darkClass = if ($Mode -eq "dark") { ' class="dark"' } else { "" }
  $swatches = ($Theme.swatch | ForEach-Object {
    '<span style="background:{0}" title="{0}"></span>' -f $_
  }) -join ""

  # card CSS mirrors the .theme section of themes/preview.html
  return @"
<!DOCTYPE html>
<html lang="en"$darkClass>
<head>
<meta charset="UTF-8">
<link rel="stylesheet" href="$($Theme.id)/theme.css">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { padding: 24px; background: #e8e8ea; }
  html.dark body { background: #17171a; }
  .theme {
    --pad: 22px;
    background: var(--bg); color: var(--text);
    border: 1px solid var(--border); border-radius: 16px;
    padding: var(--pad);
    display: flex; flex-direction: column; gap: 16px;
    font-family: var(--font-body);
  }
  .theme header h2 {
    font-family: var(--font-display);
    font-size: var(--text-2xl); line-height: var(--text-2xl--line-height);
    font-weight: 700; letter-spacing: -0.01em;
  }
  .theme header p { font-size: var(--text-sm); color: var(--text-muted); margin-top: 3px; }
  .swatches { display: flex; gap: 7px; }
  .swatches span {
    width: 26px; height: 26px; border-radius: var(--radius-full);
    border: 1px solid var(--border); cursor: default;
  }
  .btns { display: flex; gap: 8px; flex-wrap: wrap; }
  .b {
    font-family: inherit; font-size: var(--text-sm); font-weight: 600;
    padding: 8px 15px; border-radius: var(--radius-md);
    border: 1px solid transparent; cursor: pointer;
  }
  .b.primary   { background: var(--primary); color: var(--bg); }
  .b.secondary { background: var(--secondary); color: var(--bg); }
  .b.accent    { background: var(--accent); color: var(--bg); }
  .b.ghost { background: transparent; border-color: var(--border); color: var(--text); }
  .chips { display: flex; gap: 7px; flex-wrap: wrap; }
  .chip { font-size: var(--text-xs); font-weight: 600; padding: 4px 10px; border-radius: var(--radius-full); }
  .chip.success { background: var(--success-subtle); color: var(--success); }
  .chip.warning { background: var(--warning-subtle); color: var(--warning); }
  .chip.error   { background: var(--error-subtle);   color: var(--error); }
  .chip.info    { background: var(--info-subtle);    color: var(--info); }
  .field label {
    display: block; font-size: var(--text-xs); font-weight: 600;
    color: var(--text-muted); margin-bottom: 5px; letter-spacing: 0.03em;
    text-transform: uppercase;
  }
  .field input {
    width: 100%; font-family: inherit; font-size: var(--text-sm);
    padding: 9px 12px; color: var(--text);
    background: var(--surface-raised);
    border: 1px solid var(--border); border-radius: var(--radius-md);
    outline: none;
  }
  .field input::placeholder { color: var(--text-muted); opacity: 0.75; }
  .card {
    background: var(--surface-raised);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-md);
    padding: 18px;
    display: flex; flex-direction: column; gap: 8px;
  }
  .card h3 { font-family: var(--font-display); font-size: var(--text-lg); font-weight: 700; }
  .card p  { font-size: var(--text-sm); color: var(--text-muted); line-height: 1.55; }
  .card a  { font-size: var(--text-sm); font-weight: 600; text-decoration: none; color: var(--primary); align-self: flex-start; }
  .type { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
  .type .big { font-family: var(--font-display); font-size: var(--text-4xl); font-weight: 700; letter-spacing: -0.02em; }
  .type code {
    font-family: var(--font-mono); font-size: var(--text-xs);
    background: var(--surface); border: 1px solid var(--border);
    padding: 2px 7px; border-radius: var(--radius-sm); color: var(--text-muted);
  }
</style>
</head>
<body>
<section class="theme" data-theme="$($Theme.id)" data-mode="$Mode">
  <header>
    <h2>$($Theme.displayName)</h2>
    <p>$($Theme.description)</p>
  </header>
  <div class="swatches">$swatches</div>
  <div class="btns">
    <button class="b primary">Primary</button>
    <button class="b secondary">Secondary</button>
    <button class="b accent">Accent</button>
    <button class="b ghost">Ghost</button>
  </div>
  <div class="chips">
    <span class="chip success">Success</span>
    <span class="chip warning">Warning</span>
    <span class="chip error">Error</span>
    <span class="chip info">Info</span>
  </div>
  <div class="field">
    <label>Email address</label>
    <input type="text" placeholder="you@example.com">
  </div>
  <div class="card">
    <h3>Card title</h3>
    <p>Supporting copy that sits below the title, showing body text color, muted tone and line height in this theme.</p>
    <a href="#" onclick="return false">Learn more &rarr;</a>
  </div>
  <div class="type">
    <span class="big">Ag</span>
    <code>font-display</code>
    <code>radius-$($Theme.id)</code>
  </div>
</section>
</body>
</html>
"@
}

function New-GalleryHtml {
  # copy of preview.html with the mode forced (page JS reads localStorage otherwise)
  param([ValidateSet("light", "dark")][string]$Mode)

  $src = Get-Content (Join-Path $themesDir "preview.html") -Raw -Encoding UTF8
  $needle = 'apply(saved === "light" || saved === "dark" ? saved : "auto");'
  return $src.Replace($needle, "apply(`"$Mode`");")
}

# --- generate ----------------------------------------------------------------

$catalog = (Get-Content (Join-Path $themesDir "themes.json") -Raw -Encoding UTF8 | ConvertFrom-Json).themes
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$tempFiles = New-Object System.Collections.Generic.List[string]
$made = New-Object System.Collections.Generic.List[string]
$failed = New-Object System.Collections.Generic.List[string]

function Save-Shot {
  param([string]$Html, [string]$Name)
  $htmlPath = Join-Path $themesDir "_shot_$Name.html"
  $pngPath = Join-Path $OutDir "$Name.png"
  Set-Content -Path $htmlPath -Value $Html -Encoding UTF8
  $tempFiles.Add($htmlPath)

  $size = if ($Name -like "gallery-*") { "1600,3400" } else { "$Width,$Height" }
  if (Invoke-HeadlessShot -HtmlPath $htmlPath -PngPath $pngPath -Size $size) {
    $made.Add($Name)
    Write-Host "  OK   $Name.png" -ForegroundColor Green
  }
  else {
    $failed.Add($Name)
    Write-Host "  FAIL $Name.png" -ForegroundColor Red
  }
}

if (-not $CardsOnly) {
  Write-Host "Gallery shots:"
  Save-Shot (New-GalleryHtml -Mode "light") "gallery-light"
  Save-Shot (New-GalleryHtml -Mode "dark")  "gallery-dark"
}

if (-not $GalleryOnly) {
  Write-Host "Per-theme cards:"
  foreach ($t in $catalog) {
    $modes = if ($t.modes -contains "light") { @("light", "dark") } else { @("dark") }
    foreach ($m in $modes) {
      Save-Shot (New-CardHtml -Theme $t -Mode $m) "$($t.id)-$m"
    }
  }
}

foreach ($f in $tempFiles) { if (Test-Path $f) { Remove-Item $f -Force } }

Write-Host ""
Write-Host ("Generated {0} screenshot(s) -> {1}" -f $made.Count, $OutDir)
if ($failed.Count -gt 0) {
  Write-Host ("Failed: {0}" -f ($failed -join ", ")) -ForegroundColor Red
  exit 1
}
exit 0
