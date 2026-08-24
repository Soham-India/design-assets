# Design Assets

A reusable collection of design assets for all my projects.

## Structure

```
design-assets/
├── avatars/
├── backgrounds/
├── fonts/
├── icons/
├── illustrations/
├── logos/
├── patterns/
└── themes/
```

## Avatar Categories

- Humans
- Animals
- Birds
- Marine
- Insects
- Robots

## Icon Categories

85 stroke-style icons (240x240 PNG, transparent background), cataloged in `icons/icons.json`:

- UI (home, search, settings, user, heart, star, lock, calendar, ...)
- Arrows (directional arrows, chevrons, refresh, link, external-link)
- Media (play, pause, volume, mic, camera, video, music, ...)
- Files (file, folder, copy, clipboard, download, upload, ...)
- Comms (mail, phone, chat, send, share)
- Weather (sun, moon, cloud, rain, lightning, snowflake)
- Commerce (cart, tag, gift, credit-card, wallet)
- Devices (monitor, smartphone, printer, battery, wifi, bluetooth, power)

## Themes

12 pre-built UI themes in `themes/`, each with light + dark modes (except where noted). Open `themes/preview.html` in a browser to browse them all.

| Theme   | Vibe                                        |
|---------|---------------------------------------------|
| Nord    | Cool arctic blues, calm and professional    |
| Dracula | Iconic purple/pink neon dark palette        |
| Ember   | Warm terracotta and amber, cozy             |
| Forest  | Deep greens, sage and ochre, organic        |
| Ocean   | Airy teal/cyan, fresh and modern            |
| Mono    | Pure grayscale, sharp corners, mono display |
| Cyberpunk | Dark-only blueprint/terminal look, neon-blue glow (ported from AI-interview-coach) |
| Coffee  | Warm café neutrals — cream, caramel, espresso |
| High-Contrast | WCAG AAA accessibility-first, black/white, bold hues |
| Terminal | Dark-only retro CRT, phosphor-green on black |
| Rose    | Soft rose/lavender/peach pastels, gentle    |
| Dusk    | Twilight indigo, lavender, amber horizon glow |

Each theme folder contains:

- `theme.css` — CSS custom properties scoped to `[data-theme="<id>"]`. Mode follows the OS preference by default; force it with `data-mode="light"` / `data-mode="dark"` on the themed element, or add the `.dark` class on any ancestor.
- `tokens.json` — the same tokens as machine-readable JSON (`static`, `light`, `dark`).
- `tailwind.css` — Tailwind v4 mapping (`@theme inline`) so utilities like `bg-primary`, `text-muted-fg`, `border-line`, `rounded-lg`, `shadow-md` follow the active theme.

The Cyberpunk and Terminal themes are dark-only (no light mode). Both ship an extra `effects.css` with plain-CSS extras, usable with or without Tailwind:

- **Cyberpunk** — keyframes, clip-path panel cuts (`.cut-panel`, `.cut-button`), `.wireframe-grid`, `.blueprint-scan`, `.cyber-scrollbar` and scroll-reveal classes.
- **Terminal** — CRT dressing: `.crt-screen` (scanlines + vignette), `.scanlines`, `.crt-vignette`, `.crt-grid`, `.phosphor-glow` / `.phosphor-glow-amber`, `.anim-flicker`, `.anim-phosphor`, `.crt-power-on`, `.crt-sweep`, `.term-cursor`, `.term-scrollbar` (respects `prefers-reduced-motion`).

Quick start (Tailwind v4):

```css
@import "tailwindcss";
@import "../design-assets/themes/nord/theme.css";
@import "../design-assets/themes/nord/tailwind.css";
```

```html
<html data-theme="nord">
  <body class="bg-bg text-fg">...</body>
</html>
```

Plain HTML/CSS: just link `theme.css` and use `var(--bg)`, `var(--primary)`, etc.
The catalog in `themes/themes.json` lists every theme with swatches and file paths.

This repository is used across my React, Spring Boot, and future projects.
