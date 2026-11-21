#!/usr/bin/env python3
"""Render a WaveDrom JSON file to SVG styled for dark backgrounds.

Data slots get no fill; text, waveform lines, arrows and group brackets are drawn in white.
Node marker labels (the letters used to anchor edges) are removed.

Usage: render_wavedrom.py <input.json> <output.svg>
Normally run through `make timing` in docs/ (or `make timing_diagrams` at the repo root).
Requires the `wavedrom` Python package (pip install wavedrom).
"""

import re
import sys

import wavedrom

FG = "#fff"


def restyle(svg: str) -> str:
    # Data slot fills (.s5, .s7 - .s14) -> transparent
    svg = re.sub(r"(\.s(?:5|7|8|9|10|11|12|13|14)\{[^}]*?)fill:#[0-9a-fA-F]+", r"\1fill:none", svg)
    # Black / accent-blue strokes and fills -> foreground
    svg = re.sub(r"(stroke|fill):#(?:000|0041c4)\b", rf"\1:{FG}", svg)
    svg = svg.replace('fill="#000"', f'fill="{FG}"')
    # Default text colour, signal names (.info) and tick numbers (.muted)
    svg = svg.replace("text{font-size:11pt;", f"text{{fill:{FG};font-size:11pt;", 1)
    svg = re.sub(r"\.(info|muted)\{fill:#[0-9a-fA-F]+\}", rf".\1{{fill:{FG}}}", svg)
    # Drop edge-node marker labels: <g transform=...><rect style="fill:#FFF;" .../><text ...>x</text></g>
    svg = re.sub(r'<g transform="translate\([^)]*\)"><rect [^>]*fill:#FFF;[^>]*/><text[^>]*>.*?</text></g>', "", svg)
    return pad_bottom(center_transitions(svg))


def pad_bottom(svg: str, pad: int = 8) -> str:
    """Add a little room below the last lane so a trailing group bracket is not cut off."""

    def grow(m: re.Match) -> str:
        tag = m.group(0)
        height = int(re.search(r'height="(\d+)"', tag).group(1))
        tag = tag.replace(f'height="{height}"', f'height="{height + pad}"')
        return re.sub(r'viewBox="0,0,(\d+),\d+"', rf'viewBox="0,0,\1,{height + pad}"', tag)

    return re.sub(r"<svg [^>]*>", grow, svg, count=1)


# WaveDrom draws a value change as an X crossing centred CROSS_X px after the clock edge.
CROSS_X = 6


def center_transitions(svg: str) -> str:
    """Shift non-clock lanes left so value changes are centred on the clock edge.

    Each lane is shifted by CROSS_X, its last brick is repeated to fill the gap left at the end,
    and the lane is clipped to the diagram width so nothing spills past either edge.
    """
    width = max(float(x) for x in re.findall(r'<path d="m ([\d.]+),0 0,[\d.]+" id="gmark_', svg))
    clip = (f'<clipPath id="lane_clip"><rect x="0" y="-10" width="{width:g}" height="40" /></clipPath>')
    svg = svg.replace("<defs>", "<defs>" + clip, 1)

    def shift(m: re.Match) -> str:
        head, body = m.group(1), m.group(2)
        if re.search(r'xlink:href="#[pn]clk"', body) or "<use" not in body:
            return m.group(0)  # clock lanes and empty spacer lanes stay as they are
        uses = re.findall(r'<use transform="translate\(([\d.]+)\)" xlink:href="(#[^"]+)" />', body)
        last_x, last_ref = uses[-1]
        extra = f'<use transform="translate({float(last_x) + 20:g})" xlink:href="{last_ref}" />'
        body = body.replace("<text", extra + "<text", 1) if "<text" in body else body + extra
        head = head.replace('transform="translate(0,0)"', f'transform="translate(-{CROSS_X},0)"')
        return f'<g clip-path="url(#lane_clip)">{head}{body}</g></g>'

    return re.sub(r'(<g id="wavelane_draw_[^"]*" transform="translate\(0,0\)">)(.*?)</g>', shift, svg)


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    with open(src) as f:
        drawing = wavedrom.render(f.read())
    drawing.saveas(dst)
    with open(dst) as f:
        svg = f.read()
    with open(dst, "w") as f:
        f.write(restyle(svg))


if __name__ == "__main__":
    main()
