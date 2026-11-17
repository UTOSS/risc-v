#!/usr/bin/env python3
"""Replace the web-font @import that draw.io leaves in exported SVGs with an embedded @font-face.

SVGs shown through <img> (e.g. on GitHub) cannot load external stylesheets, so text would fall back
to a default font. The vendored font in docs/fonts/ is inlined as a data URI instead.

Usage: embed_svg_fonts.py <svg>...
"""
import base64
import pathlib
import re
import sys

FONTS_DIR = pathlib.Path(__file__).resolve().parent.parent / "fonts"

# Google Fonts family name (as written in the @import URL) -> (CSS family, vendored file, weights)
FONTS = {
    "Roboto+Mono": ("Roboto Mono", "RobotoMono-latin.woff2", "100 700"),
}

IMPORT_RE = re.compile(r'@import url\("https://fonts\.googleapis\.com/css2?\?family=([^":&]+)[^"]*"\);')


def font_face(family_param):
    if family_param not in FONTS:
        sys.exit(f"ERROR: no vendored font for '{family_param}'; add it to docs/fonts/ and FONTS")
    family, filename, weights = FONTS[family_param]
    data = base64.b64encode((FONTS_DIR / filename).read_bytes()).decode()
    return (f"@font-face {{ font-family: '{family}'; font-style: normal; font-weight: {weights}; "
            f"src: url(data:font/woff2;base64,{data}) format('woff2'); }}")


def main(paths):
    for path in map(pathlib.Path, paths):
        svg = path.read_text()
        out = IMPORT_RE.sub(lambda m: font_face(m.group(1)), svg)
        if "fonts.googleapis.com" in out:
            sys.exit(f"ERROR: {path} still references an external font")
        path.write_text(out)


if __name__ == "__main__":
    main(sys.argv[1:])
