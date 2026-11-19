#!/usr/bin/env python3
"""
Turn the raw OpenROAD/OpenSTA dumps written by scripts/harden.tcl into post-PnR metric reports.

Outputs:
  --csv     per-hierarchy utilization (cumulative, like the pre-PnR synthesis_utilization.csv)
  --pretty  the same as a fixed-width table
  --gates   per-cell-type breakdown of the placed design
  --timing  timing/power/floorplan summary
"""
import argparse
import csv
import json
import os
import re
import sys
from collections import defaultdict

SEQ_MARKERS = ("DFF", "DLH", "DLL", "SDFF")

# LEF CLASS values of physical-only cells that OpenROAD drops into the layout
FILLER_CLASSES = {"CORE_SPACER"}
WELLTAP_CLASSES = {"CORE_WELLTAP", "ENDCAP", "ENDCAP_PRE", "ENDCAP_POST"}

# instance name prefixes OpenROAD uses for the cells it inserts; anything with origin TIMING not
# matching these is lumped into "other repair"
INSERTED_CATEGORIES = [
    ("CTS buffers", re.compile(r"^(clkbuf|clkload|clone)")),
    ("hold buffers", re.compile(r"^hold")),
    ("DRV/setup repair buffers", re.compile(r"^(max_cap|max_length|max_slew|rebuffer|split|wire|buffer|input|output|place)")),
]


def parse_args():
    p = argparse.ArgumentParser(description="Parse OpenROAD post-PnR dumps into metric reports.")
    p.add_argument("--pnr-dir", required=True, help="Directory with cells.tsv, summary.json and *.rpt")
    p.add_argument("--csv", required=True, help="Output per-hierarchy utilization CSV")
    p.add_argument("--pretty", required=True, help="Output per-hierarchy utilization table")
    p.add_argument("--gates", required=True, help="Output gate breakdown")
    p.add_argument("--timing", required=True, help="Output timing/power summary")
    return p.parse_args()


def is_seq(master):
    return any(m in master for m in SEQ_MARKERS)


def read_cells(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def classify_inserted(name, master):
    # repair_tie_fanout clones tie cells next to their loads, naming them after the load
    if master.startswith("LOGIC"):
        return "tie cells"
    for label, rx in INSERTED_CATEGORIES:
        if rx.match(name):
            return label
    return "other repair"


def hierarchy_of(inst_name):
    """`core.u_decode_stage.RegFile._42_` -> ['core', 'core.u_decode_stage', 'core.u_decode_stage.RegFile']"""
    parts = inst_name.split(".")[:-1]
    return [".".join(parts[: i + 1]) for i in range(len(parts))]


def parse_power(path):
    """Return (internal, switching, leakage, total) in W from the `Total` row of report_power."""
    if not os.path.isfile(path):
        return None
    with open(path) as f:
        for line in f:
            if line.startswith("Total"):
                vals = line.split()[1:5]
                return tuple(float(v) for v in vals)
    return None


def parse_skew(path):
    if not os.path.isfile(path):
        return None
    with open(path) as f:
        for line in f:
            m = re.match(r"\s*(-?[\d.]+)\s+setup skew", line)
            if m:
                return float(m.group(1))
    return None


def parse_drv(path):
    """Count violators per section of `report_check_types -violators`."""
    counts = {"max slew": 0, "max capacitance": 0, "max fanout": 0}
    if not os.path.isfile(path):
        return counts
    section = None
    with open(path) as f:
        for line in f:
            s = line.strip()
            if s in counts:
                section = s
            elif section and "VIOLATED" in s:
                counts[section] += 1
    return counts


def write_text(path, content):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def main():
    args = parse_args()

    cells_tsv = os.path.join(args.pnr_dir, "cells.tsv")
    summary_json = os.path.join(args.pnr_dir, "summary.json")
    for p in (cells_tsv, summary_json):
        if not os.path.isfile(p):
            print(f"Error: required PnR dump not found: {p}", file=sys.stderr)
            sys.exit(1)

    cells = read_cells(cells_tsv)
    with open(summary_json) as f:
        summary = json.load(f)

    # ------------------------------------------------------------------
    # Aggregate
    # ------------------------------------------------------------------
    def new_bucket():
        return {"cells": 0, "area": 0.0, "comb_cells": 0, "comb_area": 0.0, "seq_cells": 0, "seq_area": 0.0}

    hier = defaultdict(new_bucket)    # hierarchy path -> bucket (cumulative)
    gates = defaultdict(lambda: [0, 0.0])  # master -> [count, area] (logic cells only)
    inserted = defaultdict(lambda: [0, 0.0])  # category -> [count, area]
    filler = [0, 0.0]
    welltap = [0, 0.0]

    for c in cells:
        name, master, klass, origin = c["instance"], c["master"], c["class"], c["origin"]
        area = float(c["area_um2"])

        if klass in FILLER_CLASSES:
            filler[0] += 1
            filler[1] += area
            continue
        if klass in WELLTAP_CLASSES:
            welltap[0] += 1
            welltap[1] += area
            continue

        gates[master][0] += 1
        gates[master][1] += area

        if origin == "TIMING":
            cat = classify_inserted(name, master)
            inserted[cat][0] += 1
            inserted[cat][1] += area
            # OpenROAD-inserted cells have no RTL home; they only count towards `top`
            nodes = ["top", "(OpenROAD-inserted)"]
        else:
            nodes = ["top"] + ["top." + h for h in hierarchy_of(name)]

        seq = is_seq(master)
        for n in nodes:
            b = hier[n]
            b["cells"] += 1
            b["area"] += area
            if seq:
                b["seq_cells"] += 1
                b["seq_area"] += area
            else:
                b["comb_cells"] += 1
                b["comb_area"] += area

    # ------------------------------------------------------------------
    # Per-hierarchy utilization
    # ------------------------------------------------------------------
    def sort_key(node):
        if node == "top":
            return (0, "")
        if node == "(OpenROAD-inserted)":
            return (2, "")
        return (1, node)

    rows = sorted(hier.items(), key=lambda kv: sort_key(kv[0]))

    os.makedirs(os.path.dirname(os.path.abspath(args.csv)), exist_ok=True)
    with open(args.csv, "w") as f:
        f.write("Hierarchy Node,Total Cells,Total Area (um^2),Combinational Cells,Combinational Area (um^2),"
                "Sequential Cells,Sequential Area (um^2)\n")
        for node, b in rows:
            f.write(f"{node},{b['cells']},{b['area']:.2f},{b['comb_cells']},{b['comb_area']:.2f},"
                    f"{b['seq_cells']},{b['seq_area']:.2f}\n")

    w = max(len("Hierarchy / Instance"), *(len(n) for n, _ in rows))
    header = (f"| {'Hierarchy / Instance':<{w}} | {'Total Cells':>11} | {'Area (um^2)':>14} | {'Comb Cells':>10} | "
              f"{'Comb Area':>14} | {'Seq Cells':>9} | {'Seq Area':>14} |")
    sep = f"|{'-' * (w + 2)}|{'-' * 13}|{'-' * 16}|{'-' * 12}|{'-' * 16}|{'-' * 11}|{'-' * 16}|"
    lines = [header, sep]
    for node, b in rows:
        lines.append(f"| {node:<{w}} | {b['cells']:11d} | {b['area']:14.2f} | {b['comb_cells']:10d} | "
                     f"{b['comb_area']:14.2f} | {b['seq_cells']:9d} | {b['seq_area']:14.2f} |")
    lines.append("")
    lines.append("Logic cells only (tap and filler cells excluded); areas are after resizing/buffering.")
    pretty = "\n".join(lines) + "\n"
    write_text(args.pretty, pretty)

    # ------------------------------------------------------------------
    # Gate breakdown
    # ------------------------------------------------------------------
    total_logic_area = sum(a for _, a in gates.values()) or 1.0
    g = ["=" * 68,
         "            OPENROAD POST-PNR GATE BREAKDOWN (Nangate45)",
         "=" * 68,
         f"{'Cell Type':<16} | {'Count':>10} | {'Total Area (um^2)':>18} | {'% Area':>8}",
         "-" * 68]
    for master, (cnt, area) in sorted(gates.items(), key=lambda kv: (-kv[1][1], kv[0])):
        g.append(f"{master:<16} | {cnt:10d} | {area:18.2f} | {area / total_logic_area * 100:7.2f}%")
    g.append("-" * 68)
    g.append(f"{'TOTAL (logic)':<16} | {sum(c for c, _ in gates.values()):10d} | {total_logic_area:18.2f} | 100.00%")
    g.append("=" * 68)
    g.append("")
    g.append(f"{'Inserted by OpenROAD':<28} | {'Count':>10} | {'Area (um^2)':>18}")
    g.append("-" * 68)
    for label in [l for l, _ in INSERTED_CATEGORIES] + ["tie cells", "other repair"]:
        cnt, area = inserted.get(label, (0, 0.0))
        g.append(f"{label:<28} | {cnt:10d} | {area:18.2f}")
    g.append(f"{'tap cells':<28} | {welltap[0]:10d} | {welltap[1]:18.2f}")
    g.append(f"{'filler cells':<28} | {filler[0]:10d} | {filler[1]:18.2f}")
    g.append("=" * 68)
    gates_txt = "\n".join(g) + "\n"
    write_text(args.gates, gates_txt)

    # ------------------------------------------------------------------
    # Timing / power / floorplan summary
    # ------------------------------------------------------------------
    period = summary["clock_period_ns"]
    setup_wns = summary["setup_wns_ns"]
    min_period = period - setup_wns
    fmax = 1000.0 / min_period if min_period > 0 else float("inf")
    core_area = summary["core_area_um2"]
    placed_area = total_logic_area + welltap[1]
    power = parse_power(os.path.join(args.pnr_dir, "power.rpt"))
    skew = parse_skew(os.path.join(args.pnr_dir, "clock_skew.rpt"))
    drv = parse_drv(os.path.join(args.pnr_dir, "drv.rpt"))

    def ns(v):
        return f"{v:9.3f} ns"

    t = ["=" * 68,
         "          OPENROAD/OPENSTA POST-PNR TIMING SUMMARY (Nangate45)",
         "=" * 68,
         f"Parasitics                       : {summary['parasitics']}",
         "",
         "-- Timing " + "-" * 58,
         f"Clock period (clk)               : {ns(period)}",
         f"Setup WNS                        : {ns(setup_wns)}",
         f"Setup TNS                        : {ns(summary['setup_tns_ns'])}",
         f"Setup violating endpoints        : {summary['setup_violating_endpoints']:9d}",
         f"Hold WNS                         : {ns(summary['hold_wns_ns'])}",
         f"Hold TNS                         : {ns(summary['hold_tns_ns'])}",
         f"Hold violating endpoints         : {summary['hold_violating_endpoints']:9d}",
         f"Min. period (period - setup WNS) : {ns(min_period)}",
         f"Est. Fmax                        : {fmax:9.2f} MHz",
         f"Clock skew (setup)               : " + (ns(skew) if skew is not None else "      n/a"),
         "",
         "-- Design rule violations " + "-" * 42,
         f"Max slew violations              : {drv['max slew']:9d}",
         f"Max capacitance violations       : {drv['max capacitance']:9d}",
         f"Max fanout violations            : {drv['max fanout']:9d}",
         "",
         "-- Area " + "-" * 60,
         f"Die area                         : {summary['die_area_um2']:12.2f} um^2",
         f"Core area                        : {core_area:12.2f} um^2",
         f"Std cell area (logic + taps)     : {placed_area:12.2f} um^2",
         f"Core utilization                 : {placed_area / core_area * 100:11.2f} %",
         f"  (floorplan target {summary['core_utilization_target_pct']}%, placement density {summary['place_density']})",
         ]
    if power:
        internal, switching, leakage, total = power
        t += ["",
              "-- Power (typical corner, 10% input activity) " + "-" * 22,
              f"Internal                         : {internal * 1e3:12.4f} mW",
              f"Switching                        : {switching * 1e3:12.4f} mW",
              f"Leakage                          : {leakage * 1e3:12.4f} mW",
              f"Total                            : {total * 1e3:12.4f} mW"]
    t.append("=" * 68)
    timing_txt = "\n".join(t) + "\n"
    write_text(args.timing, timing_txt)

    width = len(header)
    print("\n" + "=" * width)
    print("POST-PNR RESOURCE UTILIZATION (Nangate45 PDK)".center(width))
    print("=" * width)
    print(pretty)
    print(gates_txt)
    print(timing_txt)


if __name__ == "__main__":
    main()
