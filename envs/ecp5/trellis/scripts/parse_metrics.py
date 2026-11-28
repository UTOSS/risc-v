#!/usr/bin/env python3
"""
Parse Yosys ECP5 synthesis statistics and nextpnr-ecp5 PnR reports into:
  --csv      per-hierarchy post-PnR utilization CSV
  --pretty   per-hierarchy post-PnR utilization fixed-width table
  --summary  device resource utilization summary (analogous to Quartus .fit.summary)
  --timing   timing & Fmax summary (analogous to Quartus .sta.summary)
"""
import argparse
import json
import os
import sys
from collections import defaultdict


def parse_args():
    p = argparse.ArgumentParser(description="Parse ECP5 Yosys + nextpnr-ecp5 metrics.")
    p.add_argument("--synth-stats", required=True, help="Yosys synth_stats.json")
    p.add_argument("--pnr-report", required=True, help="nextpnr-ecp5 pnr_report.json")
    p.add_argument("--placed-json", required=True, help="nextpnr-ecp5 top_placed.json")
    p.add_argument("--device", default="LFE5U-25F-7BG256I", help="Target ECP5 part number")
    p.add_argument("--csv", required=True, help="Output per-hierarchy utilization CSV")
    p.add_argument("--pretty", required=True, help="Output per-hierarchy utilization table")
    p.add_argument("--summary", required=True, help="Output device utilization summary")
    p.add_argument("--timing", required=True, help="Output timing/Fmax summary")
    return p.parse_args()


def write_text(path, content):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def extract_known_hierarchy(synth_stats):
    """Extract canonical RTL instance paths from Yosys synth_stats.json module names.

    Yosys/slang names parameterized/scoped modules like:
        \\utoss_riscv$top.core -> 'top.core'
        \\ALU$top.core.u_execute_stage.alu -> 'top.core.u_execute_stage.alu'
        \\top -> 'top'
    """
    paths = {"top"}
    for mod_name in synth_stats.get("modules", {}):
        clean = mod_name.lstrip("\\")
        if "$" in clean:
            inst_path = clean.split("$", 1)[1]
            if inst_path == "top" or inst_path.startswith("top."):
                paths.add(inst_path)
    return paths


def match_hierarchy_nodes(cell_name, known_paths):
    """Return all ancestor RTL hierarchy paths (including 'top') owning cell_name."""
    # Placed cell names in flattened top have paths like 'core.u_execute_stage.alu.foo'
    # Strip any leading '\\' or '$'
    clean = cell_name.lstrip("\\")
    if clean.startswith("$"):
        return ["top"]

    parts = clean.split(".")
    # Walk prefixes of 'top.<parts>' to find the deepest known RTL module instance
    deepest = "top"
    for i in range(1, len(parts)):
        candidate = "top." + ".".join(parts[:i])
        if candidate in known_paths:
            deepest = candidate

    # Roll up cumulatively to every ancestor up to 'top'
    nodes = ["top"]
    if deepest != "top":
        rel_parts = deepest.split(".")[1:]
        for i in range(1, len(rel_parts) + 1):
            nodes.append("top." + ".".join(rel_parts[:i]))
    return nodes


def format_pct(used, avail):
    if not avail:
        return "  n/a "
    return f"{used / avail * 100:5.1f}%"


def main():
    args = parse_args()

    for path in (args.synth_stats, args.pnr_report, args.placed_json):
        if not os.path.isfile(path):
            print(f"Error: required input not found: {path}", file=sys.stderr)
            sys.exit(1)

    with open(args.synth_stats) as f:
        synth_stats = json.load(f)
    with open(args.pnr_report) as f:
        pnr_report = json.load(f)
    with open(args.placed_json) as f:
        placed = json.load(f)

    known_paths = extract_known_hierarchy(synth_stats)
    placed_cells = placed.get("modules", {}).get("top", {}).get("cells", {})

    # ------------------------------------------------------------------
    # Aggregate post-PnR utilization by RTL hierarchy
    # ------------------------------------------------------------------
    def new_bucket():
        return {"lut4": 0, "ff": 0, "bram": 0, "dsp": 0, "io": 0, "other": 0, "total": 0}

    hier = defaultdict(new_bucket)
    for p in known_paths:
        _ = hier[p]

    for cell_name, cell_info in placed_cells.items():
        ctype = cell_info.get("type", "")
        nodes = match_hierarchy_nodes(cell_name, known_paths)
        for n in nodes:
            b = hier[n]
            b["total"] += 1
            if ctype == "TRELLIS_COMB":
                b["lut4"] += 1
            elif ctype == "TRELLIS_FF":
                b["ff"] += 1
            elif ctype == "DP16KD":
                b["bram"] += 1
            elif ctype in ("MULT18X18D", "ALU54B"):
                b["dsp"] += 1
            elif ctype == "TRELLIS_IO":
                b["io"] += 1
            else:
                b["other"] += 1

    def sort_key(node):
        if node == "top":
            return (0, "")
        if node.startswith("top.memory_map"):
            return (1, node)
        if node.startswith("top.core"):
            return (2, node)
        return (3, node)

    rows = sorted(hier.items(), key=lambda kv: sort_key(kv[0]))

    # Write CSV
    csv_lines = [
        "Hierarchy Node,LUT4 (TRELLIS_COMB),FF (TRELLIS_FF),BRAM (DP16KD),DSP (MULT18X18D),IO (TRELLIS_IO),Total Cells"
    ]
    for node, b in rows:
        csv_lines.append(
            f"{node},{b['lut4']},{b['ff']},{b['bram']},{b['dsp']},{b['io']},{b['total']}"
        )
    write_text(args.csv, "\n".join(csv_lines) + "\n")

    # Write pretty table
    w = max(len("Hierarchy / Instance"), *(len(n) for n, _ in rows))
    header = (
        f"| {'Hierarchy / Instance':<{w}} | {'LUT4':>7} | {'FF':>7} | {'DP16KD':>6} | "
        f"{'DSP':>5} | {'IO':>4} | {'Total':>7} |"
    )
    sep = f"|{'-' * (w + 2)}|{'-' * 9}|{'-' * 9}|{'-' * 8}|{'-' * 7}|{'-' * 6}|{'-' * 9}|"
    pretty_lines = [header, sep]
    for node, b in rows:
        pretty_lines.append(
            f"| {node:<{w}} | {b['lut4']:7d} | {b['ff']:7d} | {b['bram']:6d} | "
            f"{b['dsp']:5d} | {b['io']:4d} | {b['total']:7d} |"
        )
    pretty_lines.append("")
    pretty_lines.append("Post-PnR counts from nextpnr-ecp5 (cumulative per RTL hierarchy instance).")
    pretty_txt = "\n".join(pretty_lines) + "\n"
    write_text(args.pretty, pretty_txt)

    # ------------------------------------------------------------------
    # Device utilization summary
    # ------------------------------------------------------------------
    util = pnr_report.get("utilization", {})

    def u(key):
        entry = util.get(key, {})
        return int(entry.get("used", 0)), int(entry.get("available", 0))

    summary_rows = [
        ("LUT4 (TRELLIS_COMB)", "TRELLIS_COMB"),
        ("Registers (TRELLIS_FF)", "TRELLIS_FF"),
        ("Block RAM 18Kb (DP16KD)", "DP16KD"),
        ("DSP 18x18 (MULT18X18D)", "MULT18X18D"),
        ("DSP ALU (ALU54B)", "ALU54B"),
        ("I/O Pins (TRELLIS_IO)", "TRELLIS_IO"),
        ("Global Clock Buf (DCCA)", "DCCA"),
        ("PLLs (EHXPLLL)", "EHXPLLL"),
    ]

    s = [
        "=" * 68,
        f"             ECP5 PLACE & ROUTE SUMMARY ({args.device})",
        "=" * 68,
        f"Device                       : {args.device}",
        "",
        "-- Device Resource Utilization " + "-" * 37,
    ]
    for label, key in summary_rows:
        used, avail = u(key)
        s.append(f"{label:<28} : {used:6d} / {avail:6d} ({format_pct(used, avail)})")

    # Also include Yosys pre-PnR primitive summary for visibility into carry/muxes
    design_cells = synth_stats.get("design", {}).get("num_cells_by_type", {})
    if design_cells:
        s += ["", "-- Yosys Synthesis Primitives (pre-PnR) " + "-" * 28]
        for ctype, cnt in sorted(design_cells.items()):
            count = int(cnt.get("count", 0)) if isinstance(cnt, dict) else int(cnt)
            s.append(f"{ctype:<28} : {count:6d}")

    s.append("=" * 68)
    summary_txt = "\n".join(s) + "\n"
    write_text(args.summary, summary_txt)

    # ------------------------------------------------------------------
    # Timing summary
    # ------------------------------------------------------------------
    fmax_map = pnr_report.get("fmax", {})
    crit_paths = pnr_report.get("critical_paths", [])

    t = [
        "=" * 68,
        f"               ECP5 TIMING SUMMARY ({args.device})",
        "=" * 68,
    ]
    if fmax_map:
        for clk_name in sorted(fmax_map):
            info = fmax_map[clk_name]
            achieved = float(info.get("achieved", 0.0))
            constraint = float(info.get("constraint", 0.0))
            min_period = 1000.0 / achieved if achieved > 0 else float("inf")
            target_period = 1000.0 / constraint if constraint > 0 else float("inf")
            slack = target_period - min_period if (achieved > 0 and constraint > 0) else 0.0
            status = "PASS" if achieved >= constraint else "FAIL"
            t += [
                f"Clock                        : {clk_name}",
                f"Target frequency             : {constraint:9.2f} MHz ({target_period:.3f} ns)",
                f"Achieved Fmax                : {achieved:9.2f} MHz ({min_period:.3f} ns)",
                f"Setup slack                  : {slack:+9.3f} ns",
                f"Timing status                : {status}",
            ]
    else:
        t.append("No constrained clocks reported.")

    if crit_paths:
        cp = crit_paths[0]
        hops = cp.get("path", [])
        logic_ns = sum(float(h.get("delay", 0.0)) for h in hops if h.get("type") != "routing")
        route_ns = sum(float(h.get("delay", 0.0)) for h in hops if h.get("type") == "routing")
        total_ns = logic_ns + route_ns
        src_cell = hops[0]["from"]["cell"] if hops else "n/a"
        dst_cell = hops[-1]["to"]["cell"] if hops else "n/a"
        t += [
            "",
            "-- Worst Critical Path " + "-" * 45,
            f"From                         : {src_cell}",
            f"To                           : {dst_cell}",
            f"Logic delay                  : {logic_ns:9.3f} ns ({logic_ns / total_ns * 100 if total_ns else 0:.1f}%)",
            f"Routing delay                : {route_ns:9.3f} ns ({route_ns / total_ns * 100 if total_ns else 0:.1f}%)",
            f"Total path delay             : {total_ns:9.3f} ns ({len(hops)} segments)",
        ]

    t.append("=" * 68)
    timing_txt = "\n".join(t) + "\n"
    write_text(args.timing, timing_txt)

    print(summary_txt)
    print(pretty_txt)
    print(timing_txt)


if __name__ == "__main__":
    main()
