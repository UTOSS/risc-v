#!/usr/bin/env python3
"""
Draw the checked-in DE1-SoC (Cyclone V) placement figures from scripts/dump_placement.tcl's dump.

    plot_placement.py --placement output_files/placement.tsv \
        --fit-summary output_files/utoss-risc-v.fit.summary --out-dir images/RV32I --config RV32I

Figures:
  placement.png  where the Fitter put each element, colored by RTL module (zoomed to the used region)
  resources.png  logic cells, registers and memory blocks used by each RTL module

Output is byte-for-byte reproducible for a given matplotlib version (bundled fonts, no PNG metadata,
sorted input). Module colors match envs/hardening/scripts/plot_layout.py.
"""
import argparse
import csv
import os
import re
from collections import OrderedDict, defaultdict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.collections import PolyCollection  # noqa: E402
from matplotlib.lines import Line2D  # noqa: E402
from matplotlib.patches import Patch, Rectangle  # noqa: E402
from matplotlib.ticker import MaxNLocator  # noqa: E402

# Instance-path prefixes (instance names, `.`-separated, below `top`), matched in order so children
# come before their parents. Same groups and colors as the hardening figures.
MODULES = [
    ("memory_map",                  "memory_map (instr/data memory)", "#4C72B0"),
    ("core.u_fetch_stage",          "fetch_stage",                    "#DD8452"),
    ("core.u_decode_stage.RegFile", "decode_stage.RegFile",           "#55A868"),
    ("core.u_decode_stage",         "decode_stage (rest)",            "#8CD17D"),
    ("core.u_execute_stage.alu",    "execute_stage.alu",              "#C44E52"),
    ("core.u_execute_stage",        "execute_stage (rest)",           "#FF9D9A"),
    ("core.u_memory_stage",         "memory_stage",                   "#8172B3"),
    ("core.u_write_back_stage",     "write_back_stage",               "#937860"),
    ("core.u_hazard_unit",          "hazard_unit",                    "#DA8BC3"),
    ("core",                        "core glue logic",                "#8C8C8C"),
]
OTHER = ("top level / other", "#BBBBBB")

FIG_SIZE = (12.0, 8.4)
DPI = 130

LOC_RE = re.compile(r"^(?P<kind>[A-Z0-9]+?)_X(?P<x>\d+)_Y(?P<y>\d+)_N(?P<n>\d+)$")


def instance_path(full_name):
    """`|top|utoss_riscv:core|ALU:alu|Add0~1` -> `core.alu` (instance names of the hierarchy)."""
    parts = [p for p in full_name.split("|") if p]
    insts = [p.split(":", 1)[1] for p in parts if ":" in p]
    return ".".join(insts)


def classify(full_name):
    path = instance_path(full_name)
    for prefix, label, color in MODULES:
        if path == prefix or path.startswith(prefix + "."):
            return label, color
    return OTHER


def element_kind(loc_kind):
    if loc_kind in ("LABCELL", "MLABCELL"):
        return "logic"
    if loc_kind == "FF":
        return "register"
    if loc_kind.startswith("M10K"):
        return "m10k"
    if loc_kind.startswith("DSP"):
        return "dsp"
    return "other"


def read_placement(path):
    elements = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            label, color = classify(r["name"])
            m = LOC_RE.match(r["location"]) or LOC_RE.match(r["element"])
            e = {"type": r["type"], "label": label, "color": color, "name": r["name"],
                 "location": r["location"]}
            if m:
                e.update(kind=element_kind(m["kind"]) if r["type"] != "io" else "io",
                         x=int(m["x"]), y=int(m["y"]), n=int(m["n"]))
            else:
                e.update(kind="io" if r["type"] == "io" else "other", x=None, y=None, n=0)
            elements.append(e)
    return elements


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
    fig.savefig(path, dpi=DPI, metadata={"Software": None})
    plt.close(fig)
    print(f"wrote {path}")


def module_order(elements):
    labels = [label for _, label, _ in MODULES] + [OTHER[0]]
    colors = {label: color for _, label, color in MODULES}
    colors[OTHER[0]] = OTHER[1]
    present = {e["label"] for e in elements}
    return [(label, colors[label]) for label in labels if label in present]


def fig_placement(elements, summary, out, config):
    placed = [e for e in elements if e["x"] is not None]
    xs = [e["x"] for e in placed]
    ys = [e["y"] for e in placed]
    pad = 2
    x0, x1 = max(0, min(xs) - pad), max(xs) + pad + 1
    y0, y1 = max(0, min(ys) - pad), max(ys) + pad + 1

    fig = plt.figure(figsize=FIG_SIZE, dpi=DPI)
    ax = fig.add_axes([0.06, 0.07, 0.56, 0.80], anchor="NW")
    header(fig, "DE1-SoC placement",
           f"{config}  ·  {summary.get('device', 'Cyclone V')}  ·  where the Quartus Fitter placed each "
           "element, colored by RTL module")

    # light background square for every device tile that holds something
    tiles = sorted({(e["x"], e["y"]) for e in placed})
    ax.add_collection(PolyCollection(
        [((x, y), (x + 1, y), (x + 1, y + 1), (x, y + 1)) for x, y in tiles],
        facecolors="#F3F3F3", edgecolors="#DDDDDD", linewidths=0.4, zorder=1))

    # elements inside a logic tile (LAB): spread by their index N within the tile so the tile's fill
    # is visible; logic cells as squares, registers as dots
    def in_tile(e, cols=8):
        slot = e["n"] // 2 if e["kind"] == "logic" else e["n"]
        return (e["x"] + 0.1 + 0.8 * ((slot % cols) + 0.5) / cols,
                e["y"] + 0.1 + 0.8 * (((slot // cols) % cols) + 0.5) / cols)

    handles = []
    for label, color in module_order(placed):
        group = [e for e in placed if e["label"] == label]
        logic = [in_tile(e) for e in group if e["kind"] == "logic"]
        regs = [in_tile(e) for e in group if e["kind"] == "register"]
        rams = [e for e in group if e["kind"] in ("m10k", "dsp")]
        ios = [e for e in group if e["kind"] == "io"]
        if logic:
            ax.scatter(*zip(*logic), s=9, marker="s", color=color, linewidths=0, zorder=3)
        if regs:
            ax.scatter(*zip(*regs), s=7, marker="o", color=color, edgecolors="black",
                       linewidths=0.25, zorder=4)
        for e in rams:
            ax.add_patch(Rectangle((e["x"] + 0.05, e["y"] + 0.05), 0.9, 0.9, facecolor=color,
                                   edgecolor="black", linewidth=1.0, zorder=5))
        for e in ios:
            ax.scatter([e["x"] + 0.5], [e["y"] + 0.5], s=40, marker="D", color=color,
                       edgecolors="black", linewidths=0.6, zorder=6)
        handles.append(Patch(color=color, label=f"{label} ({len(group)})"))

    handles += [
        Line2D([], [], ls="", marker="s", markersize=4, color="#666666", label="logic cell (LUT)"),
        Line2D([], [], ls="", marker="o", markersize=4, color="#666666", markeredgecolor="black",
               markeredgewidth=0.3, label="register"),
        Patch(facecolor="white", edgecolor="black", label="M10K memory block"),
        Patch(facecolor="#F3F3F3", edgecolor="#DDDDDD", label="device tile in use"),
    ]
    if any(e["kind"] == "io" for e in placed):
        handles.append(Line2D([], [], ls="", marker="D", markersize=6, color="white",
                              markeredgecolor="black", label="I/O pin"))
    ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(1.04, 1.0), frameon=False,
              fontsize=9, title="Module (placed elements)", title_fontsize=10, alignment="left")

    # device X/Y are tile indices, not distances, so the used region is stretched to fill the plot
    ax.set_xlim(x0, x1)
    ax.set_ylim(y0, y1)
    ax.set_xlabel("device column X  (tile index; tiles stretched to fill the plot)")
    ax.set_ylabel("device row Y")
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))
    ax.yaxis.set_major_locator(MaxNLocator(integer=True))
    ax.tick_params(labelsize=8)

    note = [f"{k:<12} {v}" for k, v in summary.items() if k != "device"]
    note.append(f"view: X {x0}..{x1 - 1}, Y {y0}..{y1 - 1} (region in use)")
    unplaced = sum(1 for e in elements if e["x"] is None)
    if unplaced:
        note.append(f"not drawn: {unplaced} I/O pins")
        note.append("  (reported by package pin, no grid site)")
    fig.text(0.66, 0.07, "\n".join(note), ha="left", va="bottom", fontsize=8.5, color="#444444",
             family="DejaVu Sans Mono", linespacing=1.5)
    save(fig, out)


def fig_resources(elements, summary, out, config):
    order = module_order(elements)
    counts = defaultdict(lambda: defaultdict(int))
    for e in elements:
        counts[e["label"]][e["kind"]] += 1

    metrics = [("logic", "logic cells (LUTs)"), ("register", "registers"),
               ("m10k", "M10K memory blocks"), ("io", "I/O pins")]
    fig, axes = plt.subplots(1, len(metrics), figsize=(12.0, 6.0), dpi=DPI, sharey=True)
    fig.subplots_adjust(left=0.22, right=0.98, top=0.80, bottom=0.10, wspace=0.12)
    header(fig, "DE1-SoC resources by module",
           f"{config}  ·  {summary.get('device', 'Cyclone V')}  ·  placed elements per RTL module")

    labels = [label for label, _ in order][::-1]
    colors = [color for _, color in order][::-1]
    for ax, (kind, title) in zip(axes, metrics):
        vals = [counts[label][kind] for label in labels]
        ax.barh(range(len(labels)), vals, color=colors, height=0.7)
        total = sum(vals)
        ax.set_title(f"{title}\n(total {total})", fontsize=10)
        vmax = max(vals) if any(vals) else 1
        for i, v in enumerate(vals):
            if v:
                ax.text(v + vmax * 0.02, i, str(v), va="center", fontsize=8)
        ax.set_xlim(0, vmax * 1.25)
        ax.tick_params(labelsize=8)
        for side in ("top", "right"):
            ax.spines[side].set_visible(False)
    axes[0].set_yticks(range(len(labels)))
    axes[0].set_yticklabels(labels, fontsize=9)
    save(fig, out)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--placement", required=True, help="TSV written by scripts/dump_placement.tcl")
    p.add_argument("--fit-summary", help="Quartus .fit.summary, for the utilization note")
    p.add_argument("--out-dir", required=True, help="where to write the PNG figures")
    p.add_argument("--config", required=True, help="UTOSS_RISCV_CONFIG, shown in the figure titles")
    args = p.parse_args()

    plt.rcParams.update({"font.family": "DejaVu Sans", "figure.facecolor": "white",
                         "savefig.facecolor": "white", "path.simplify": False})
    os.makedirs(args.out_dir, exist_ok=True)
    elements = read_placement(args.placement)
    summary = read_fit_summary(args.fit_summary)
    fig_placement(elements, summary, os.path.join(args.out_dir, "placement.png"), args.config)
    fig_resources(elements, summary, os.path.join(args.out_dir, "resources.png"), args.config)


if __name__ == "__main__":
    main()
