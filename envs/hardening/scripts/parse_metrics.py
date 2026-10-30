#!/usr/bin/env python3
"""
Parse Yosys JSON statistics and generate CSV, pretty table, and gate breakdown.
"""
import argparse
import json
import os
import sys

def parse_args():
    parser = argparse.ArgumentParser(description="Parse Yosys synthesis statistics.")
    parser.add_argument("--json", required=True, help="Path to input stats.json")
    parser.add_argument("--csv", required=True, help="Path to output utilization CSV")
    parser.add_argument("--pretty", required=True, help="Path to output pretty-printed txt")
    parser.add_argument("--gates", required=True, help="Path to output gate breakdown txt")
    return parser.parse_args()

def main():
    args = parse_args()

    if not os.path.isfile(args.json):
        print(f"Error: JSON file not found: {args.json}", file=sys.stderr)
        sys.exit(1)

    with open(args.json, "r") as f:
        data = json.load(f)

    modules = data.get("modules", {})
    if not modules:
        print("Warning: No modules found in stats.json", file=sys.stderr)
        return

    rows = []
    top_gate_counts = {}
    top_gate_areas = {}

    for mod_name, mod_info in modules.items():
        clean_name = mod_name.lstrip("\\")
        cells = mod_info.get("num_cells_by_type", {})
        total_cells = sum(int(c.get("count", 0)) for c in cells.values())
        total_area = sum(float(c.get("area", 0.0)) for c in cells.values())
        seq_cells = sum(int(c.get("count", 0)) for name, c in cells.items() if any(x in name for x in ("DFF", "DLH", "DLL")))
        seq_area = sum(float(c.get("area", 0.0)) for name, c in cells.items() if any(x in name for x in ("DFF", "DLH", "DLL")))
        comb_cells = total_cells - seq_cells
        comb_area = total_area - seq_area

        if clean_name == "top":
            for name, c in cells.items():
                top_gate_counts[name] = int(c.get("count", 0))
                top_gate_areas[name] = float(c.get("area", 0.0))

        rows.append({
            "Module": clean_name,
            "Total Cells": total_cells,
            "Total Area": round(total_area, 2),
            "Comb Cells": comb_cells,
            "Comb Area": round(comb_area, 2),
            "Seq Cells": seq_cells,
            "Seq Area": round(seq_area, 2)
        })

    def sort_key(r):
        name = r["Module"]
        if name == "top":
            return (0, "")
        elif "utoss_riscv" in name:
            return (1, name)
        elif "memory_map" in name:
            return (3, name)
        else:
            return (2, name)

    rows.sort(key=sort_key)

    # Write CSV
    os.makedirs(os.path.dirname(os.path.abspath(args.csv)), exist_ok=True)
    with open(args.csv, "w") as f:
        f.write("Hierarchy Node,Total Cells,Total Area (um^2),Combinational Cells,Combinational Area (um^2),Sequential Cells,Sequential Area (um^2)\n")
        for r in rows:
            f.write(f"{r['Module']},{r['Total Cells']},{r['Total Area']:.2f},{r['Comb Cells']},{r['Comb Area']:.2f},{r['Seq Cells']},{r['Seq Area']:.2f}\n")

    # Format Pretty Text
    mod_col_width = max(len("Hierarchy / Module"), *(len(r["Module"]) for r in rows)) if rows else 55
    header = f"| {'Hierarchy / Module':<{mod_col_width}} | {'Total Cells':>11} | {'Area (um^2)':>14} | {'Comb Cells':>10} | {'Comb Area':>14} | {'Seq Cells':>9} | {'Seq Area':>14} |"
    sep = f"|{'-' * (mod_col_width + 2)}|{'-' * 13}|{'-' * 16}|{'-' * 12}|{'-' * 16}|{'-' * 11}|{'-' * 16}|"
    pretty_lines = [header, sep]
    for r in rows:
        line = f"| {r['Module']:<{mod_col_width}} | {r['Total Cells']:11d} | {r['Total Area']:14.2f} | {r['Comb Cells']:10d} | {r['Comb Area']:14.2f} | {r['Seq Cells']:9d} | {r['Seq Area']:14.2f} |"
        pretty_lines.append(line)

    pretty_content = "\n".join(pretty_lines) + "\n"
    os.makedirs(os.path.dirname(os.path.abspath(args.pretty)), exist_ok=True)
    with open(args.pretty, "w") as f:
        f.write(pretty_content)

    # Format Gate Breakdown
    gate_lines = []
    gate_lines.append("=" * 68)
    gate_lines.append("                YOSYS GATE BREAKDOWN SUMMARY (Nangate45)")
    gate_lines.append("=" * 68)
    gate_lines.append(f"{'Cell Type':<16} | {'Count':>10} | {'Total Area (um^2)':>18} | {'% Area':>8}")
    gate_lines.append("-" * 68)

    total_top_area = sum(top_gate_areas.values()) if top_gate_areas else 1.0
    sorted_gates = sorted(top_gate_counts.items(), key=lambda x: top_gate_areas.get(x[0], 0), reverse=True)
    for cell_name, count in sorted_gates:
        c_area = top_gate_areas.get(cell_name, 0.0)
        pct = (c_area / total_top_area) * 100.0 if total_top_area > 0 else 0.0
        gate_lines.append(f"{cell_name:<16} | {count:10d} | {c_area:18.2f} | {pct:7.2f}%")
    gate_lines.append("-" * 68)
    total_top_cells = sum(top_gate_counts.values())
    gate_lines.append(f"{'TOTAL':<16} | {total_top_cells:10d} | {total_top_area:18.2f} | 100.00%")
    gate_lines.append("=" * 68)

    gate_content = "\n".join(gate_lines) + "\n"
    os.makedirs(os.path.dirname(os.path.abspath(args.gates)), exist_ok=True)
    with open(args.gates, "w") as f:
        f.write(gate_content)

    # Print summary to stdout
    banner_width = len(header)
    print("\n" + "=" * banner_width)
    print("SYNTHESIS RESOURCE UTILIZATION (Nangate45 PDK)".center(banner_width))
    print("=" * banner_width)
    print(pretty_content)
    print(gate_content)

if __name__ == "__main__":
    main()
