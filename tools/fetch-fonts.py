import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "fonts")

CDN = "https://cdn.jsdelivr.net/fontsource/fonts/{slug}@latest/{subset}-{weight}-{style}.woff2"
API = "https://api.fontsource.org/v1/fonts/{slug}"

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")

FONTS = [
    {
        "id": "inter",
        "displayName": "Inter",
        "description": "Neutral screen-first sans-serif. The safe default for product UI.",
        "category": "sans",
        "designer": "Rasmus Andersson",
        "license": "SIL OFL 1.1",
        "tags": ["ui", "neutral", "modern", "interface"],
        "subsets": ["latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "jetbrains-mono",
        "displayName": "JetBrains Mono",
        "description": "Code-focused monospace with tall x-height and unambiguous glyphs.",
        "category": "mono",
        "designer": "JetBrains",
        "license": "SIL OFL 1.1",
        "tags": ["code", "monospace", "terminal", "developer"],
        "subsets": ["latin"],
        "styles": [[400, "normal"], [700, "normal"]],
    },
    {
        "id": "lora",
        "displayName": "Lora",
        "description": "Well-hyped contemporary serif with brushed curves, calm at body sizes.",
        "category": "serif",
        "designer": "Cyreal",
        "license": "SIL OFL 1.1",
        "tags": ["editorial", "body", "elegant", "blog"],
        "subsets": ["latin"],
        "styles": [[400, "normal"], [400, "italic"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "space-grotesk",
        "displayName": "Space Grotesk",
        "description": "Geometric grotesque with quirky details, built for display headlines.",
        "category": "display",
        "designer": "Florian Karsten",
        "license": "SIL OFL 1.1",
        "tags": ["display", "headline", "geometric", "techy"],
        "subsets": ["latin"],
        "styles": [[400, "normal"], [500, "normal"], [700, "normal"]],
    },
    {
        "id": "caveat",
        "displayName": "Caveat",
        "description": "Casual handwriting face, friendly for annotations and callouts.",
        "category": "handwriting",
        "designer": "Impallari Type",
        "license": "SIL OFL 1.1",
        "tags": ["handwritten", "casual", "annotation", "friendly"],
        "subsets": ["latin"],
        "styles": [[400, "normal"], [700, "normal"]],
    },
    {
        "id": "playfair-display",
        "displayName": "Playfair Display",
        "description": "High-contrast transitional serif, dramatic at large editorial sizes.",
        "category": "serif",
        "designer": "Claus Eggers Sorensen",
        "license": "SIL OFL 1.1",
        "tags": ["editorial", "headline", "elegant", "magazine"],
        "subsets": ["latin"],
        "styles": [[400, "normal"], [600, "normal"], [700, "normal"], [800, "normal"]],
    },
    {
        "id": "noto-sans-devanagari",
        "displayName": "Noto Sans Devanagari",
        "description": "Noto's Devanagari workhorse - complete coverage for Hindi, Marathi, Sanskrit and Nepali.",
        "category": "sans",
        "designer": "Google / Noto",
        "license": "SIL OFL 1.1",
        "tags": ["devanagari", "hindi", "ui", "script"],
        "subsets": ["devanagari", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "mukta",
        "displayName": "Mukta",
        "description": "Humanist Devanagari + Latin sans from Ek Type, a popular Hindi UI face.",
        "category": "sans",
        "designer": "Ek Type",
        "license": "SIL OFL 1.1",
        "tags": ["devanagari", "hindi", "ui", "humanist"],
        "subsets": ["devanagari", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "tiro-devanagari-hindi",
        "displayName": "Tiro Devanagari Hindi",
        "description": "Classical literary serif for Hindi with true italics, made for long-form text.",
        "category": "serif",
        "designer": "Tiro Typeworks",
        "license": "SIL OFL 1.1",
        "tags": ["devanagari", "hindi", "editorial", "literary"],
        "subsets": ["devanagari", "latin"],
        "styles": [[400, "normal"], [400, "italic"]],
    },
    {
        "id": "rozha-one",
        "displayName": "Rozha One",
        "description": "High-contrast Devanagari + Latin display face for dramatic headlines.",
        "category": "display",
        "designer": "Indian Type Foundry",
        "license": "SIL OFL 1.1",
        "tags": ["devanagari", "hindi", "display", "headline"],
        "subsets": ["devanagari", "latin"],
        "styles": [[400, "normal"]],
    },
    {
        "id": "noto-sans-oriya",
        "displayName": "Noto Sans Oriya",
        "description": "Noto's Odia script sans - clean, complete UI text coverage.",
        "category": "sans",
        "designer": "Google / Noto",
        "license": "SIL OFL 1.1",
        "tags": ["odia", "oriya", "ui", "script"],
        "subsets": ["oriya", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "baloo-bhaina-2",
        "displayName": "Baloo Bhaina 2",
        "description": "Rounded, friendly Odia display face from the Baloo superfamily.",
        "category": "display",
        "designer": "Ek Type",
        "license": "SIL OFL 1.1",
        "tags": ["odia", "oriya", "display", "playful"],
        "subsets": ["oriya", "latin"],
        "styles": [[400, "normal"], [700, "normal"]],
    },
    {
        "id": "catamaran",
        "displayName": "Catamaran",
        "description": "Tamil + Latin sans with a modern geometric feel, readable at text sizes.",
        "category": "sans",
        "designer": "Pria Ravichandran",
        "license": "SIL OFL 1.1",
        "tags": ["tamil", "ui", "geometric"],
        "subsets": ["tamil", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "hind-siliguri",
        "displayName": "Hind Siliguri",
        "description": "Bengali + Latin sans from Indian Type Foundry, built for UI and wayfinding.",
        "category": "sans",
        "designer": "Indian Type Foundry",
        "license": "SIL OFL 1.1",
        "tags": ["bengali", "ui", "humanist"],
        "subsets": ["bengali", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "noto-sans-telugu",
        "displayName": "Noto Sans Telugu",
        "description": "Noto's Telugu script sans - clean, complete UI text coverage.",
        "category": "sans",
        "designer": "Google / Noto",
        "license": "SIL OFL 1.1",
        "tags": ["telugu", "ui", "script"],
        "subsets": ["telugu", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "noto-sans-gujarati",
        "displayName": "Noto Sans Gujarati",
        "description": "Noto's Gujarati script sans - clean, complete UI text coverage.",
        "category": "sans",
        "designer": "Google / Noto",
        "license": "SIL OFL 1.1",
        "tags": ["gujarati", "ui", "script"],
        "subsets": ["gujarati", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "noto-sans-kannada",
        "displayName": "Noto Sans Kannada",
        "description": "Noto's Kannada script sans - clean, complete UI text coverage.",
        "category": "sans",
        "designer": "Google / Noto",
        "license": "SIL OFL 1.1",
        "tags": ["kannada", "ui", "script"],
        "subsets": ["kannada", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "noto-sans-gurmukhi",
        "displayName": "Noto Sans Gurmukhi",
        "description": "Noto's Gurmukhi (Punjabi) script sans - clean, complete UI text coverage.",
        "category": "sans",
        "designer": "Google / Noto",
        "license": "SIL OFL 1.1",
        "tags": ["gurmukhi", "punjabi", "ui", "script"],
        "subsets": ["gurmukhi", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
    {
        "id": "noto-sans-malayalam",
        "displayName": "Noto Sans Malayalam",
        "description": "Noto's Malayalam script sans - clean, complete UI text coverage.",
        "category": "sans",
        "designer": "Google / Noto",
        "license": "SIL OFL 1.1",
        "tags": ["malayalam", "ui", "script"],
        "subsets": ["malayalam", "latin"],
        "styles": [[400, "normal"], [500, "normal"], [600, "normal"], [700, "normal"]],
    },
]

_meta_cache = {}


def http_get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def is_woff2(data):
    return isinstance(data, bytes) and len(data) >= 4 and data[:4] == b"wOF2"


def fetch_meta(slug):
    if slug not in _meta_cache:
        try:
            meta = json.loads(http_get(API.format(slug=slug)).decode("utf-8"))
            _meta_cache[slug] = {"subsets": meta.get("subsets", []),
                                 "ranges": meta.get("unicodeRange", {})}
        except Exception:
            _meta_cache[slug] = None
    return _meta_cache[slug]


def from_fontsource(slug, weight, style, subset):
    url = CDN.format(slug=slug, subset=subset, weight=weight, style=style)
    data = http_get(url)
    if not is_woff2(data):
        raise ValueError(f"not woff2: {url}")
    return data


def from_google_css(display_name, weight, style, subset):
    fam = urllib.parse.quote(display_name)
    axis = f"{1 if style == 'italic' else 0},{weight}"
    url = f"https://fonts.googleapis.com/css2?family={fam}:ital,wght@{axis}"
    css = http_get(url).decode("utf-8")
    found = re.findall(r"/\*\s*([a-z0-9-]+)\s*\*/\s*@font-face\s*\{[^}]*?"
                       r"url\((https://[^)]+\.woff2)\)", css)
    urls = [u for s, u in found if s == subset]
    if not urls:
        raise ValueError(f"no '{subset}' woff2 in google css for {display_name}")
    data = http_get(urls[0])
    if not is_woff2(data):
        raise ValueError(f"not woff2 from google css: {display_name} {subset}")
    return data


def fetch_one(font, weight, style, subset, force=False):
    fid = font["id"]
    name = f"{fid}-{subset}-{weight}-{style}.woff2"
    dest_dir = os.path.join(OUT, fid)
    dest = os.path.join(dest_dir, name)

    if not force and os.path.exists(dest):
        with open(dest, "rb") as fh:
            if is_woff2(fh.read(4)):
                print(f"  skip  {fid}/{name} (exists)")
                return dest

    os.makedirs(dest_dir, exist_ok=True)
    errors = []
    sources = (lambda: from_fontsource(fid, weight, style, subset),
               lambda: from_google_css(font["displayName"], weight, style, subset))
    for source in sources:
        try:
            data = source()
            break
        except Exception as exc:  # noqa: BLE001 - fall through to next source
            errors.append(str(exc))
    else:
        raise RuntimeError(f"failed {name}: " + " | ".join(errors))

    tmp = dest + ".tmp"
    with open(tmp, "wb") as fh:
        fh.write(data)
    os.replace(tmp, dest)
    print(f"  got   {fid}/{name} ({len(data) // 1024} KB)")
    return dest


def prune(fid, keep):
    d = os.path.join(OUT, fid)
    if not os.path.isdir(d):
        return
    for name in sorted(os.listdir(d)):
        if name.endswith(".woff2") and name not in keep:
            os.remove(os.path.join(d, name))
            print(f"  prune {fid}/{name}")


def rel(path):
    return os.path.relpath(path, OUT).replace(os.sep, "/")


def write_css(entries):
    lines = [
        "/* Generated by tools/fetch-fonts.py - do not edit by hand.",
        "   Self-hosted unicode-range subsets, SIL OFL 1.1. See LICENSES.md. */",
        "",
    ]
    for font, files, ranges in entries:
        lines.append(f'/* {font["displayName"]} */')
        for subset, path, weight, style in files:
            lines += [
                "@font-face {",
                f'  font-family: "{font["displayName"]}";',
                f"  font-style: {style};",
                f"  font-weight: {weight};",
                "  font-display: swap;",
                f'  src: url("{path}") format("woff2");',
            ]
            rng = ranges.get(subset)
            if rng:
                lines.append(f"  unicode-range: {rng};")
            lines.append("}")
            lines.append("")
    with open(os.path.join(OUT, "fonts.css"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def write_catalog(entries):
    catalog = {"fonts": []}
    for font, files, ranges in entries:
        catalog["fonts"].append({
            "id": font["id"],
            "displayName": font["displayName"],
            "description": font["description"],
            "category": font["category"],
            "designer": font["designer"],
            "license": font["license"],
            "tags": font["tags"],
            "subsets": sorted({s for s, _, _, _ in files}),
            "weights": sorted({w for _, _, w, _ in files}),
            "hasItalic": any(st == "italic" for _, _, _, st in files),
            "css": "fonts.css",
            "unicodeRange": ranges,
            "files": [p for _, p, _, _ in files],
        })
    catalog["fonts"].sort(key=lambda f: f["id"])
    with open(os.path.join(OUT, "fonts.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(catalog, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


def main():
    ap = argparse.ArgumentParser(
        description="Fetch self-hosted woff2 fonts and build fonts.css/fonts.json")
    ap.add_argument("--force", action="store_true", help="re-download even if files exist")
    args = ap.parse_args()

    entries = []
    failures = 0
    count = 0
    for font in FONTS:
        print(font["displayName"])
        meta = fetch_meta(font["id"])
        ranges = meta["ranges"] if meta else {}
        got = []
        for subset in font.get("subsets", ["latin"]):
            if meta and meta["subsets"] and subset not in meta["subsets"]:
                print(f"  warn  subset '{subset}' not offered upstream, skipping")
                continue
            for weight, style in font["styles"]:
                try:
                    dest = fetch_one(font, weight, style, subset, force=args.force)
                    got.append((subset, rel(dest), weight, style))
                except Exception as exc:  # noqa: BLE001 - report all failures at end
                    print(f"  FAIL  {subset} {weight} {style}: {exc}", file=sys.stderr)
                    failures += 1
        prune(font["id"], {os.path.basename(p) for _, p, _, _ in got})
        count += len(got)
        entries.append((font, got, ranges))

    write_css(entries)
    write_catalog(entries)
    total = sum(os.path.getsize(os.path.join(OUT, p))
                for _, files, _ in entries for _, p, _, _ in files)
    print(f"\n{len(FONTS)} families, {count} woff2 files, {total // 1024} KB total -> fonts/")
    if failures:
        print(f"{failures} downloads failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
