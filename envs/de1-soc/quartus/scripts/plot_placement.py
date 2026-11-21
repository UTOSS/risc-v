#!/usr/bin/env python3
"""
Draw the checked-in DE1-SoC (Cyclone V) placement figure from scripts/dump_placement.tcl's dump.

    plot_placement.py --placement output_files/placement.tsv \
        --fit-summary output_files/utoss-risc-v.fit.summary --out-dir images/RV32I --config RV32I

Figure:
  placement.png  the region of the device the design uses, like the Chip Planner's default view:
                 each logic tile (LAB) in use is shaded by how many of its sites are used, and each
                 M10K memory block in use is filled in

Output is byte-for-byte reproducible for a given matplotlib version (bundled fonts, no PNG metadata,
sorted input).
"""
import argparse
import csv
import os
import re
from collections import Counter, OrderedDict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.collections import PolyCollection  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap, Normalize  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402
from matplotlib.ticker import MaxNLocator, PercentFormatter  # noqa: E402

FIG_SIZE = (12.0, 8.4)
DPI = 130
LAB_SITES = 60   # placement sites per logic tile: 10 ALMs x (2 LUT halves + 4 registers)

# colors after the Chip Planner: light to dark blue for logic tiles by usage, olive for memory
LAB_CMAP = LinearSegmentedColormap.from_list("lab_usage", ["#C9D8EE", "#2F5FA8"])
M10K_COLOR = "#84914C"
GRID_COLOR = "#E4E4E4"

LOC_RE = re.compile(r"^(?P<kind>[A-Z0-9]+?)_X(?P<x>\d+)_Y(?P<y>\d+)_N(?P<n>\d+)$")


def read_placement(path):
    """Count used sites per tile: {(x, y): n} for logic tiles, and the set of used M10K tiles."""
    lab, m10k, unplaced = Counter(), set(), 0
    with open(path, newline="") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            m = LOC_RE.match(r["location"])
            if not m:
                unplaced += 1   # I/O pins report a package pin (PIN_AF14), not a grid site
                continue
            tile = (int(m["x"]), int(m["y"]))
            if m["kind"] in ("LABCELL", "MLABCELL", "FF"):
                lab[tile] += 1
            elif m["kind"].startswith("M10K"):
                m10k.add(tile)
    return lab, m10k, unplaced


def read_fit_summary(path):
    keys = OrderedDict([("Device", "device"), ("Logic utilization (in ALMs)", "ALMs"),
                        ("Total registers", "registers"), ("Total pins", "pins"),
                        ("Total RAM Blocks", "M10K blocks"), ("Total DSP Blocks", "DSP blocks")])
    out = OrderedDict()
    if path and os.path.isfile(path):
        with open(path) as f:
            for line in f:
                k, _, v = line.partition(" : ")
                if k.strip() in keys:
                    out[keys[k.strip()]] = v.strip()
    return out


def header(fig, title, subtitle):
    fig.text(0.06, 0.955, title, ha="left", va="center", fontsize=16, fontweight="bold")
    fig.text(0.06, 0.915, subtitle, ha="left", va="center", fontsize=10, color="#555555")


def save(fig, path):
    fig.savefig(path, dpi=fig.dpi, metadata={"Software": None})
    plt.close(fig)
    print(f"wrote {path}")


def square(x, y):
    return ((x, y), (x + 1, y), (x + 1, y + 1), (x, y + 1))


def _fit_span(lo, hi, span):
    lo -= (span - (hi - lo)) // 2
    if lo < 0:
        lo = 0
    return lo, lo + span


def fig_placement(lab, m10k, unplaced, summary, out, config):
    tiles = set(lab) | m10k
    xs = [x for x, _ in tiles]
    ys = [y for _, y in tiles]
    pad = 2
    x0, x1 = max(0, min(xs) - pad), max(xs) + pad + 1
    y0, y1 = max(0, min(ys) - pad), max(ys) + pad + 1
    # make the view a square window (1:1 map of tiles): grow the shorter axis around its center,
    # shifting right/up instead of going below tile 0
    span = max(x1 - x0, y1 - y0)
    x0, x1 = _fit_span(x0, x1, span)
    y0, y1 = _fit_span(y0, y1, span)

    fig = plt.figure(figsize=FIG_SIZE, dpi=DPI)
    ax = fig.add_axes([0.06, 0.07, 0.56, 0.80], anchor="NW")
    header(fig, "DE1-SoC placement",
           f"{config}  ·  {summary.get('device', 'Cyclone V')}  ·  device tiles used by the Quartus "
           "Fitter")

    # faint grid of every tile in view; the device's own layout (which columns are logic, memory
    # or DSP) isn't available from the Tcl API, so unused tiles are left blank
    ax.add_collection(PolyCollection(
        [square(x, y) for x in range(x0, x1) for y in range(y0, y1)],
        facecolors="none", edgecolors=GRID_COLOR, linewidths=0.4, zorder=1))

    norm = Normalize(0, 1)
    labs = sorted(lab)
    ax.add_collection(PolyCollection(
        [square(x, y) for x, y in labs],
        facecolors=[LAB_CMAP(norm(lab[t] / LAB_SITES)) for t in labs],
        edgecolors="white", linewidths=0.5, zorder=2))
    if m10k:
        ax.add_collection(PolyCollection(
            [square(x, y) for x, y in sorted(m10k)],
            facecolors=M10K_COLOR, edgecolors="white", linewidths=0.5, zorder=2))

    cax = fig.add_axes([0.66, 0.80, 0.22, 0.022])
    cbar = fig.colorbar(plt.cm.ScalarMappable(norm=norm, cmap=LAB_CMAP), cax=cax,
                        orientation="horizontal", format=PercentFormatter(1.0))
    cbar.set_ticks([0, 0.25, 0.5, 0.75, 1.0])
    cbar.ax.tick_params(labelsize=8)
    cbar.outline.set_linewidth(0.5)
    cax.set_title(f"logic tile (LAB) usage: used sites / {LAB_SITES}", fontsize=9, loc="left")
    fig.legend(handles=[Patch(facecolor=M10K_COLOR, label="M10K memory block in use")],
               loc="upper left", bbox_to_anchor=(0.655, 0.74), frameon=False, fontsize=9)

    ax.set_xlim(x0, x1)
    ax.set_ylim(y0, y1)
    ax.set_aspect("equal", adjustable="box", anchor="NW")
    ax.set_xlabel("device column X  (tile index)")
    ax.set_ylabel("device row Y")
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))
    ax.yaxis.set_major_locator(MaxNLocator(integer=True))
    ax.tick_params(labelsize=8)

    used = sum(lab.values())
    note = [f"{k:<12} {v}" for k, v in summary.items() if k != "device"]
    note.append(f"LABs in use  {len(lab)}  (avg {used / max(len(lab), 1) / LAB_SITES:.0%} of sites)")
    note.append(f"view: X {x0}..{x1 - 1}, Y {y0}..{y1 - 1} (region in use)")
    if unplaced:
        note.append(f"not drawn: {unplaced} I/O pins")
        note.append("  (reported by package pin, no grid site)")
    fig.text(0.66, 0.07, "\n".join(note), ha="left", va="bottom", fontsize=8.5, color="#444444",
             family="DejaVu Sans Mono", linespacing=1.5)
    save(fig, out)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--placement", required=True, help="TSV written by scripts/dump_placement.tcl")
    p.add_argument("--fit-summary", help="Quartus .fit.summary, for the utilization note")
    p.add_argument("--out-dir", required=True, help="where to write the PNG figure")
    p.add_argument("--config", required=True, help="UTOSS_RISCV_CONFIG, shown in the figure title")
    args = p.parse_args()

    plt.rcParams.update({"font.family": "DejaVu Sans", "figure.facecolor": "white",
                         "savefig.facecolor": "white", "path.simplify": False})
    os.makedirs(args.out_dir, exist_ok=True)
    lab, m10k, unplaced = read_placement(args.placement)
    summary = read_fit_summary(args.fit_summary)
    fig_placement(lab, m10k, unplaced, summary, os.path.join(args.out_dir, "placement.png"),
                  args.config)


if __name__ == "__main__":
    main()
