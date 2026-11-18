#!/usr/bin/env python3
"""
Draw the checked-in hardening layout figures from the data dumped by scripts/dump_layout.tcl.

    plot_layout.py --dump-dir out/layout --out-dir images/RV32I --config RV32I

Expects one sub-directory per stage snapshot in --dump-dir: 1_floorplan, 2_place, 3_cts and top
(final). The output is byte-for-byte reproducible for a given matplotlib version: fonts are the
ones bundled with matplotlib, PNG metadata is stripped and all inputs are sorted.
"""
import argparse
import csv
import os
from collections import OrderedDict, defaultdict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from matplotlib.collections import LineCollection, PolyCollection  # noqa: E402
from matplotlib.lines import Line2D  # noqa: E402
from matplotlib.patches import Patch, Rectangle  # noqa: E402

# ---------------------------------------------------------------------------------------------
# What the module figure colors. Prefixes are instance-name prefixes of the flattened netlist,
# matched in order (so children must come before their parents).
# ---------------------------------------------------------------------------------------------
MODULES = [
    ("u_memory_map",                          "memory_map (instr/data memory)", "#4C72B0"),
    ("core.u_fetch_stage",                    "fetch_stage",                    "#DD8452"),
    ("core.u_decode_stage.RegFile",           "decode_stage.RegFile",           "#55A868"),
    ("core.u_decode_stage",                   "decode_stage (rest)",            "#8CD17D"),
    ("core.u_execute_stage.alu",              "execute_stage.alu",              "#C44E52"),
    ("core.u_execute_stage",                  "execute_stage (rest)",           "#FF9D9A"),
    ("core.u_memory_stage",                   "memory_stage",                   "#8172B3"),
    ("core.u_write_back_stage",               "write_back_stage",               "#937860"),
    ("core.u_hazard_unit",                    "hazard_unit",                    "#DA8BC3"),
    ("core",                                  "core glue logic",                "#8C8C8C"),
]
INSERTED = ("inserted by OpenROAD (buffers, tie cells)", "#CFCFCF")
UNASSIGNED = ("other", "#E5E5E5")

SEQ_MARKERS = ("DFF", "DLH", "DLL", "SDFF")

POWER_LAYER_STYLE = {
    "metal1": ("#9DB4D3", "metal1 rails (follow cell rows)"),
    "metal4": ("#2E8B57", "metal4 stripes"),
    "metal7": ("#C2185B", "metal7 stripes"),
}

FIG_SIZE = (12.0, 8.4)
DPI = 130
DIE_COLOR = "#222222"
CORE_COLOR = "#777777"


# ---------------------------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------------------------
def read_tsv(path):
    if not os.path.isfile(path):
        return []
    with open(path, newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def read_meta(stage_dir):
    meta = {r["key"]: r["value"] for r in read_tsv(os.path.join(stage_dir, "meta.tsv"))}
    return {
        "design": meta.get("design", "top"),
        "die": [float(v) for v in meta["die"].split()],
        "core": [float(v) for v in meta["core"].split()],
    }


def read_cells(stage_dir):
    cells = []
    for r in read_tsv(os.path.join(stage_dir, "cells.tsv")):
        r["box"] = tuple(float(r[k]) for k in ("x0", "y0", "x1", "y1"))
        cells.append(r)
    return cells


def read_heatmap(path):
    """Return (x_edges, y_edges, grid[y][x]) from a gui::dump_heatmap CSV."""
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            rows.append(tuple(float(r[k]) for k in ("x0", "y0", "x1", "y1", "value")))
    xs = sorted({r[0] for r in rows} | {r[2] for r in rows})
    ys = sorted({r[1] for r in rows} | {r[3] for r in rows})
    xi = {v: i for i, v in enumerate(xs)}
    yi = {v: i for i, v in enumerate(ys)}
    grid = np.full((len(ys) - 1, len(xs) - 1), np.nan)
    for x0, y0, _, _, v in rows:
        grid[yi[y0], xi[x0]] = v
    return np.array(xs), np.array(ys), grid


# ---------------------------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------------------------
def boxes_to_polys(boxes):
    return [((x0, y0), (x1, y0), (x1, y1), (x0, y1)) for x0, y0, x1, y1 in boxes]


def add_boxes(ax, boxes, color, zorder=2, alpha=1.0, edge=False):
    if not boxes:
        return
    pc = PolyCollection(boxes_to_polys(boxes), facecolors=color, alpha=alpha, zorder=zorder,
                        edgecolors=(DIE_COLOR if edge else "none"), linewidths=(0.2 if edge else 0))
    ax.add_collection(pc)


def new_figure(meta, config, title, subtitle):
    fig = plt.figure(figsize=FIG_SIZE, dpi=DPI)
    ax = fig.add_axes([0.06, 0.07, 0.56, 0.80], anchor="NW")
    fig.text(0.06, 0.955, title, ha="left", va="center", fontsize=16, fontweight="bold")
    fig.text(0.06, 0.915, f"{config}  ·  Nangate45  ·  {subtitle}", ha="left", va="center",
             fontsize=10, color="#555555")
    dx0, dy0, dx1, dy1 = meta["die"]
    pad = 0.02 * (dx1 - dx0)
    ax.set_xlim(dx0 - pad, dx1 + pad)
    ax.set_ylim(dy0 - pad, dy1 + pad)
    ax.set_aspect("equal")
    ax.set_xlabel("x (µm)")
    ax.set_ylabel("y (µm)")
    ax.tick_params(labelsize=8)
    for spine in ax.spines.values():
        spine.set_visible(False)
    return fig, ax


def draw_outlines(ax, meta, label=True):
    dx0, dy0, dx1, dy1 = meta["die"]
    cx0, cy0, cx1, cy1 = meta["core"]
    ax.add_patch(Rectangle((dx0, dy0), dx1 - dx0, dy1 - dy0, fill=False, lw=1.4, ec=DIE_COLOR,
                           zorder=10))
    ax.add_patch(Rectangle((cx0, cy0), cx1 - cx0, cy1 - cy0, fill=False, lw=0.8, ls="--",
                           ec=CORE_COLOR, zorder=10))
    handles = []
    if label:
        handles = [Line2D([], [], color=DIE_COLOR, lw=1.4,
                          label=f"die  {dx1 - dx0:.1f} × {dy1 - dy0:.1f} µm"),
                   Line2D([], [], color=CORE_COLOR, lw=0.8, ls="--",
                          label=f"core {cx1 - cx0:.1f} × {cy1 - cy0:.1f} µm")]
    return handles


def side_legend(ax, handles, title=None):
    leg = ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(1.04, 1.0), frameon=False,
                    fontsize=9, title=title, title_fontsize=10, alignment="left",
                    handlelength=1.6, borderaxespad=0)
    return leg


def side_note(fig, lines):
    fig.text(0.66, 0.07, "\n".join(lines), ha="left", va="bottom", fontsize=8.5, color="#444444",
             family="DejaVu Sans Mono", linespacing=1.5)


def save(fig, path):
    fig.savefig(path, dpi=DPI, metadata={"Software": None})
    plt.close(fig)
    print(f"wrote {path}")


def is_seq(master):
    return any(m in master for m in SEQ_MARKERS)


def box_area(b):
    return (b[2] - b[0]) * (b[3] - b[1])


def logic_cells(cells):
    return [c for c in cells if c["class"] == "CORE"]


# ---------------------------------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------------------------------
def fig_floorplan(stage_dir, out, config):
    meta = read_meta(stage_dir)
    cells = read_cells(stage_dir)
    power = read_tsv(os.path.join(stage_dir, "power.tsv"))
    pins = read_tsv(os.path.join(stage_dir, "pins.tsv"))

    fig, ax = new_figure(meta, config, "Floorplan",
                         "die, core, power grid, tap cells and I/O pins before placement")
    handles = draw_outlines(ax, meta)

    by_layer = defaultdict(list)
    for p in power:
        by_layer[p["layer"]].append(tuple(float(p[k]) for k in ("x0", "y0", "x1", "y1")))
    for layer in sorted(by_layer, key=lambda l: int(l.replace("metal", ""))):
        color, label = POWER_LAYER_STYLE.get(layer, ("#999999", f"{layer} stripes"))
        z = 3 + int(layer.replace("metal", ""))
        add_boxes(ax, by_layer[layer], color, zorder=z, alpha=0.85 if layer == "metal1" else 1.0)
        handles.append(Patch(color=color, label=f"{label} ({len(by_layer[layer])})"))

    taps = [c["box"] for c in cells if c["class"] == "CORE_WELLTAP"]
    add_boxes(ax, taps, "#333333", zorder=15)
    handles.append(Patch(color="#333333", label=f"tap cells ({len(taps)})"))

    # I/O pins: draw each as a marker on the die edge, and label each bus once
    groups = OrderedDict()
    supply = [p for p in pins if p["pin"].rstrip("0123456789").rstrip("_[") in ("VDD", "VSS")]
    pins = [p for p in pins if p not in supply]
    for p in pins:
        base = p["pin"].rstrip("0123456789").rstrip("_[") or p["pin"]
        x = (float(p["x0"]) + float(p["x1"])) / 2
        y = (float(p["y0"]) + float(p["y1"])) / 2
        groups.setdefault(base, []).append((x, y))
    pin_colors = ["#E4572E", "#17BEBB", "#FFC914", "#76B041", "#9055A2"]
    for i, (name, pts) in enumerate(groups.items()):
        pts = np.array(pts)
        color = pin_colors[i % len(pin_colors)]
        ax.scatter(pts[:, 0], pts[:, 1], s=30, marker="D", color=color, edgecolor="black",
                   linewidths=0.4, zorder=20)
        label = f"{name}[{len(pts) - 1}:0]" if len(pts) > 1 else name
        handles.append(Line2D([], [], ls="", marker="D", color=color, markeredgecolor="black",
                              markeredgewidth=0.4, label=f"pin {label}"))

    side_legend(ax, handles, "Legend")
    cx0, cy0, cx1, cy1 = meta["core"]
    logic_area = sum(box_area(c["box"]) for c in logic_cells(cells))
    side_note(fig, [
        f"core area      {(cx1 - cx0) * (cy1 - cy0):10.0f} µm²",
        f"logic to place {logic_area:10.0f} µm²",
        f"target util.   {logic_area / ((cx1 - cx0) * (cy1 - cy0)) * 100:10.1f} %",
        f"signal pins    {len(pins):10d}",
        f"supply pins    {len(supply):10d}  (VDD/VSS on metal7)",
    ])
    save(fig, out)


def density_grid(meta, boxes, bin_um):
    """Fraction of each bin_um x bin_um core bin covered by the given cell boxes (in %)."""
    cx0, cy0, cx1, cy1 = meta["core"]
    nx = int(np.ceil((cx1 - cx0) / bin_um))
    ny = int(np.ceil((cy1 - cy0) / bin_um))
    grid = np.zeros((ny, nx))
    for x0, y0, x1, y1 in boxes:
        # cells are much smaller than a bin; split each across the bins it overlaps
        for ix in range(int((x0 - cx0) // bin_um), int((x1 - cx0) // bin_um) + 1):
            for iy in range(int((y0 - cy0) // bin_um), int((y1 - cy0) // bin_um) + 1):
                if not (0 <= ix < nx and 0 <= iy < ny):
                    continue
                bx0, by0 = cx0 + ix * bin_um, cy0 + iy * bin_um
                ox = min(x1, bx0 + bin_um) - max(x0, bx0)
                oy = min(y1, by0 + bin_um) - max(y0, by0)
                if ox > 0 and oy > 0:
                    grid[iy, ix] += ox * oy
    xs = cx0 + np.arange(nx + 1) * bin_um
    ys = cy0 + np.arange(ny + 1) * bin_um
    xs[-1], ys[-1] = cx1, cy1
    area = np.outer(np.diff(ys), np.diff(xs))
    return xs, ys, grid / area * 100


def fig_placement(stage_dir, out, config):
    meta = read_meta(stage_dir)
    cells = read_cells(stage_dir)
    bin_um = 5.0

    fig, ax = new_figure(meta, config, "Placement density",
                         "share of each 5 µm bin covered by logic cells, after placement (before CTS)")
    handles = draw_outlines(ax, meta)
    logic = logic_cells(cells)
    xs, ys, grid = density_grid(meta, [c["box"] for c in logic], bin_um)
    mesh = ax.pcolormesh(xs, ys, grid, cmap="viridis", vmin=0, vmax=100, zorder=1)
    side_legend(ax, handles, "Legend")

    cax = fig.add_axes([0.66, 0.42, 0.25, 0.022])
    cb = fig.colorbar(mesh, cax=cax, orientation="horizontal")
    cb.set_label(f"cell area per {bin_um:g} µm bin (%)", fontsize=9)
    cb.ax.tick_params(labelsize=8)

    seq = sum(1 for c in logic if is_seq(c["master"]))
    side_note(fig, [
        f"logic cells     {len(logic):8d}",
        f"  sequential    {seq:8d}",
        f"  combinational {len(logic) - seq:8d}",
        f"density mean    {grid.mean():8.1f} %",
        f"density max     {grid.max():8.1f} %",
        f"bins > 90 %     {(grid > 90).mean() * 100:8.1f} %",
    ])
    save(fig, out)


def fig_clock_tree(stage_dir, out, config):
    meta = read_meta(stage_dir)
    cells = read_cells(stage_dir)
    edges = read_tsv(os.path.join(stage_dir, "clock.tsv"))

    fig, ax = new_figure(meta, config, "Clock tree",
                         "clock nets from the clk pin through the CTS buffer levels to the flip-flops")
    handles = draw_outlines(ax, meta)
    add_boxes(ax, [c["box"] for c in logic_cells(cells)], "#EFEFEF", zorder=1)

    levels = sorted({int(e["level"]) for e in edges})
    max_level = max(levels) if levels else 0
    # root levels dark and thick, the last level (buffers -> flip-flops) light and thin
    palette = ["#2D0A4E", "#7B1FA2", "#D81B60", "#F57C00", "#9E9E9E"]
    for level in levels:
        segs = [((float(e["x0"]), float(e["y0"])), (float(e["x1"]), float(e["y1"])))
                for e in edges if int(e["level"]) == level]
        is_leaf = level == max_level
        color = palette[-1] if is_leaf else palette[min(level, len(palette) - 2)]
        width = 0.3 if is_leaf else max(0.8, 2.4 - 0.4 * level)
        ax.add_collection(LineCollection(segs, colors=[color], linewidths=width,
                                         alpha=0.7 if is_leaf else 1.0,
                                         zorder=(4 if is_leaf else 10 - level)))
        what = "buffers -> flip-flops" if is_leaf else ("clk pin -> root buffer" if level == 0
                                                         else "buffer -> buffer")
        handles.append(Line2D([], [], color=color, lw=max(width, 1.0),
                              label=f"level {level}: {what} ({len(segs)})"))
    flops = sum(1 for e in edges if is_seq(e["sink_master"]))

    bufs = [c for c in cells if c["name"].startswith("clkbuf")]
    pts = np.array([((c["box"][0] + c["box"][2]) / 2, (c["box"][1] + c["box"][3]) / 2)
                    for c in bufs]) if bufs else np.zeros((0, 2))
    ax.scatter(pts[:, 0], pts[:, 1], s=7, color="black", zorder=20, linewidths=0)
    handles.append(Line2D([], [], ls="", marker="o", markersize=3.5, color="black",
                          label=f"clock buffers ({len(bufs)})"))
    handles.append(Patch(color="#EFEFEF", label="other cells"))
    side_legend(ax, handles, "Legend")
    side_note(fig, [f"buffer levels    {len(levels) - 1:6d}",
                    f"clock buffers    {len(bufs):6d}",
                    f"flip-flop sinks  {flops:6d}",
                    f"dummy loads      {sum(1 for c in cells if c['name'].startswith('clkload')):6d}",
                    "  (clkload*: balance leaf loads)"])
    save(fig, out)


def fig_modules(stage_dir, out, config):
    meta = read_meta(stage_dir)
    cells = read_cells(stage_dir)

    fig, ax = new_figure(meta, config, "RTL modules",
                         "placed cells colored by the RTL module they were synthesized from")
    handles = draw_outlines(ax, meta)

    groups = OrderedDict((label, (color, [])) for _, label, color in MODULES)
    groups[INSERTED[0]] = (INSERTED[1], [])
    groups[UNASSIGNED[0]] = (UNASSIGNED[1], [])
    for c in logic_cells(cells):
        if c["origin"] == "TIMING":
            groups[INSERTED[0]][1].append(c["box"])
            continue
        for prefix, label, _ in MODULES:
            if c["name"].startswith(prefix + "."):
                groups[label][1].append(c["box"])
                break
        else:
            groups[UNASSIGNED[0]][1].append(c["box"])

    total = sum(box_area(b) for _, boxes in groups.values() for b in boxes) or 1.0
    for z, (label, (color, boxes)) in enumerate(groups.items()):
        if not boxes:
            continue
        add_boxes(ax, boxes, color, zorder=3 + z)
        area = sum(box_area(b) for b in boxes)
        handles.append(Patch(color=color, label=f"{label}\n{len(boxes):6d} cells · "
                                                f"{area:8.0f} µm² · {area / total * 100:4.1f} %"))
    side_legend(ax, handles, "Module · cells · area · share")
    save(fig, out)


def fig_congestion(stage_dir, out, config):
    meta = read_meta(stage_dir)
    xs, ys, grid = read_heatmap(os.path.join(stage_dir, "routing_heatmap.csv"))

    fig, ax = new_figure(meta, config, "Routing congestion",
                         "global-routing resource usage per routing tile (final layout)")
    handles = draw_outlines(ax, meta)
    mesh = ax.pcolormesh(xs, ys, grid, cmap="turbo", vmin=0, vmax=100, zorder=1)
    side_legend(ax, handles, "Legend")

    cax = fig.add_axes([0.66, 0.42, 0.25, 0.022])
    cb = fig.colorbar(mesh, cax=cax, orientation="horizontal")
    cb.set_label("routing resource usage (%)", fontsize=9)
    cb.ax.tick_params(labelsize=8)

    vals = grid[~np.isnan(grid)]
    side_note(fig, [
        f"tile size      {xs[1] - xs[0]:7.1f} µm",
        f"usage mean     {vals.mean():7.1f} %",
        f"usage max      {vals.max():7.1f} %",
        f"tiles > 80 %   {(vals > 80).mean() * 100:7.2f} %",
        f"tiles > 100 %  {(vals > 100).mean() * 100:7.2f} %",
    ])
    save(fig, out)


FIGURES = [
    ("floorplan.png",  "1_floorplan", fig_floorplan),
    ("placement.png",  "2_place",     fig_placement),
    ("clocktree.png",  "3_cts",       fig_clock_tree),
    ("modules.png",    "top",         fig_modules),
    ("congestion.png", "top",         fig_congestion),
]


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dump-dir", required=True, help="output of scripts/dump_layout.tcl, one dir per stage")
    p.add_argument("--out-dir", required=True, help="where to write the PNG figures")
    p.add_argument("--config", required=True, help="UTOSS_RISCV_CONFIG, shown in the figure titles")
    args = p.parse_args()

    plt.rcParams.update({
        "font.family": "DejaVu Sans",
        "figure.facecolor": "white",
        "axes.facecolor": "white",
        "savefig.facecolor": "white",
        "path.simplify": False,
    })
    os.makedirs(args.out_dir, exist_ok=True)
    for name, stage, func in FIGURES:
        func(os.path.join(args.dump_dir, stage), os.path.join(args.out_dir, name), args.config)


if __name__ == "__main__":
    main()
