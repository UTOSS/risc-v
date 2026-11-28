#!/usr/bin/env python3
"""
Draw the checked-in ECP5 placement figure from nextpnr-ecp5's placed netlist (`--write`)
and JSON report (`--report`).

    plot_placement.py --placed-json out/top_placed.json \
        --pnr-report out/pnr_report.json --device LFE5U-25F-7BG256I \
        --out-dir images/RV32I --config RV32I

Figure:
  placement.png  the region of the ECP5 device the design uses, analogous to DE1-SoC's
                 Chip Planner view:
                   - each PLC logic tile in use is shaded blue by how many of its 16 sites
                     are used (4 slices x (2 LUT4 + 2 FF))
                   - each DP16KD (18 Kb EBR) block in use is filled in olive
                   - each MULT18X18D/ALU54B DSP block in use is filled in amber
                   - each I/O tile in use within the view is outlined/filled in coral

Output is byte-for-byte reproducible for a given matplotlib version (bundled fonts, no PNG
metadata, sorted input).
"""
import argparse
import json
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
PLC_SITES = 16  # placement sites per ECP5 PLC tile: 4 slices x (2 LUT4 + 2 FF)

# Colors matching envs/de1-soc/quartus/scripts/plot_placement.py
PLC_CMAP = LinearSegmentedColormap.from_list("plc_usage", ["#C9D8EE", "#2F5FA8"])
EBR_COLOR = "#84914C"
DSP_COLOR = "#D9822B"
IO_COLOR = "#C95B4C"
GRID_COLOR = "#E4E4E4"

BEL_RE = re.compile(r"^X(?P<x>\d+)/Y(?P<y>\d+)/(?P<bel>.+)$")


def read_placement(path):
    """Parse placed cells from nextpnr-ecp5 JSON (`--write`)."""
    with open(path) as f:
        data = json.load(f)

    plc = Counter()
    ebr, dsp, io_tiles = set(), set(), set()
    cells = data.get("modules", {}).get("top", {}).get("cells", {})
    for cell in cells.values():
        bel = cell.get("attributes", {}).get("NEXTPNR_BEL", "")
        m = BEL_RE.match(bel)
        if not m:
            continue
        tile = (int(m["x"]), int(m["y"]))
        ctype = cell.get("type", "")
        if ctype in ("TRELLIS_COMB", "TRELLIS_FF"):
            plc[tile] += 1
        elif ctype == "DP16KD":
            ebr.add(tile)
        elif ctype in ("MULT18X18D", "ALU54B"):
            dsp.add(tile)
        elif ctype == "TRELLIS_IO":
            io_tiles.add(tile)
    return plc, ebr, dsp, io_tiles


def read_report_summary(path, device):
    """Extract concise summary stats from nextpnr-ecp5 --report JSON."""
    out = OrderedDict()
    out["device"] = device
    if not path or not os.path.isfile(path):
        return out
    with open(path) as f:
        rep = json.load(f)

    util = rep.get("utilization", {})

    def fmt_u(key):
        e = util.get(key, {})
        used, avail = int(e.get("used", 0)), int(e.get("available", 0))
        pct = f" ({used / avail * 100:.1f}%)" if avail else ""
        return f"{used:,} / {avail:,}{pct}"

    out["LUT4s"] = fmt_u("TRELLIS_COMB")
    out["registers"] = fmt_u("TRELLIS_FF")
    out["DP16KD BRAM"] = fmt_u("DP16KD")
    out["DSP blocks"] = fmt_u("MULT18X18D")
    out["I/O pins"] = fmt_u("TRELLIS_IO")

    fmax = rep.get("fmax", {})
    if fmax:
        first_clk = sorted(fmax)[0]
        info = fmax[first_clk]
        achieved = float(info.get("achieved", 0.0))
        constraint = float(info.get("constraint", 0.0))
        status = "PASS" if achieved >= constraint else "FAIL"
        out["Fmax (clk)"] = f"{achieved:.2f} MHz ({status} @ {constraint:.0f} MHz)"

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


def fig_placement(plc, ebr, dsp, io_tiles, summary, out, config):
    # Focus the zoomed square window on logic + memory + DSP tiles; draw I/Os that fall inside it
    core_tiles = set(plc) | ebr | dsp
    xs = [x for x, _ in core_tiles]
    ys = [y for _, y in core_tiles]
    pad = 2
    x0, x1 = max(0, min(xs) - pad), max(xs) + pad + 1
    y0, y1 = max(0, min(ys) - pad), max(ys) + pad + 1

    span = max(x1 - x0, y1 - y0)
    x0, x1 = _fit_span(x0, x1, span)
    y0, y1 = _fit_span(y0, y1, span)

    visible_io = sorted(t for t in io_tiles if x0 <= t[0] < x1 and y0 <= t[1] < y1)
    outside_io = len(io_tiles) - len(visible_io)

    fig = plt.figure(figsize=FIG_SIZE, dpi=DPI)
    ax = fig.add_axes([0.06, 0.07, 0.56, 0.80], anchor="NW")
    header(
        fig,
        "ECP5 placement",
        f"{config}  ·  {summary.get('device', 'ECP5')}  ·  device tiles used by nextpnr-ecp5",
    )

    ax.add_collection(
        PolyCollection(
            [square(x, y) for x in range(x0, x1) for y in range(y0, y1)],
            facecolors="none",
            edgecolors=GRID_COLOR,
            linewidths=0.4,
            zorder=1,
        )
    )

    norm = Normalize(0, 1)
    plcs = sorted(plc)
    ax.add_collection(
        PolyCollection(
            [square(x, y) for x, y in plcs],
            facecolors=[PLC_CMAP(norm(min(plc[t], PLC_SITES) / PLC_SITES)) for t in plcs],
            edgecolors="white",
            linewidths=0.5,
            zorder=2,
        )
    )

    legend_handles = []
    if ebr:
        ax.add_collection(
            PolyCollection(
                [square(x, y) for x, y in sorted(ebr)],
                facecolors=EBR_COLOR,
                edgecolors="white",
                linewidths=0.5,
                zorder=2,
            )
        )
        legend_handles.append(Patch(facecolor=EBR_COLOR, label="DP16KD memory block in use"))
    if dsp:
        ax.add_collection(
            PolyCollection(
                [square(x, y) for x, y in sorted(dsp)],
                facecolors=DSP_COLOR,
                edgecolors="white",
                linewidths=0.5,
                zorder=2,
            )
        )
        legend_handles.append(Patch(facecolor=DSP_COLOR, label="MULT18X18D DSP block in use"))
    if visible_io:
        ax.add_collection(
            PolyCollection(
                [square(x, y) for x, y in visible_io],
                facecolors=IO_COLOR,
                edgecolors="white",
                linewidths=0.5,
                zorder=3,
            )
        )
        legend_handles.append(Patch(facecolor=IO_COLOR, label="TRELLIS_IO pin tile in use"))

    cax = fig.add_axes([0.66, 0.80, 0.22, 0.022])
    cbar = fig.colorbar(
        plt.cm.ScalarMappable(norm=norm, cmap=PLC_CMAP),
        cax=cax,
        orientation="horizontal",
        format=PercentFormatter(1.0),
    )
    cbar.set_ticks([0, 0.25, 0.5, 0.75, 1.0])
    cbar.ax.tick_params(labelsize=8)
    cbar.outline.set_linewidth(0.5)
    cax.set_title(f"logic tile (PLC) usage: used sites / {PLC_SITES}", fontsize=9, loc="left")

    if legend_handles:
        fig.legend(
            handles=legend_handles,
            loc="upper left",
            bbox_to_anchor=(0.655, 0.74),
            frameon=False,
            fontsize=9,
        )

    ax.set_xlim(x0, x1)
    ax.set_ylim(y0, y1)
    ax.set_aspect("equal", adjustable="box", anchor="NW")
    ax.set_xlabel("device column X  (tile index)")
    ax.set_ylabel("device row Y")
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))
    ax.yaxis.set_major_locator(MaxNLocator(integer=True))
    ax.tick_params(labelsize=8)

    used = sum(plc.values())
    note = [f"{k:<12} {v}" for k, v in summary.items() if k != "device"]
    note.append(f"PLCs in use  {len(plc)}  (avg {used / max(len(plc), 1) / PLC_SITES:.0%} of sites)")
    note.append(f"view: X {x0}..{x1 - 1}, Y {y0}..{y1 - 1} (region in use)")
    if outside_io:
        note.append(f"not drawn: {outside_io} I/O tiles outside view")
    fig.text(
        0.66,
        0.07,
        "\n".join(note),
        ha="left",
        va="bottom",
        fontsize=8.5,
        color="#444444",
        family="DejaVu Sans Mono",
        linespacing=1.5,
    )
    save(fig, out)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--placed-json", required=True, help="nextpnr-ecp5 --write JSON")
    p.add_argument("--pnr-report", help="nextpnr-ecp5 --report JSON")
    p.add_argument("--device", default="LFE5U-25F-7BG256I", help="Target ECP5 part number")
    p.add_argument("--out-dir", required=True, help="where to write the PNG figure")
    p.add_argument("--config", required=True, help="UTOSS_RISCV_CONFIG, shown in the figure title")
    args = p.parse_args()

    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "figure.facecolor": "white",
            "savefig.facecolor": "white",
            "path.simplify": False,
        }
    )
    os.makedirs(args.out_dir, exist_ok=True)
    plc, ebr, dsp, io_tiles = read_placement(args.placed_json)
    summary = read_report_summary(args.pnr_report, args.device)
    fig_placement(
        plc,
        ebr,
        dsp,
        io_tiles,
        summary,
        os.path.join(args.out_dir, "placement.png"),
        args.config,
    )


if __name__ == "__main__":
    main()
