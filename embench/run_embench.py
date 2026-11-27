#!/usr/bin/env python3
"""Parallel Verilator runner and CPI report generator for Embench-IoT."""

import argparse
import concurrent.futures
import json
import math
import os
import re
import subprocess
import sys
import time
from pathlib import Path

RESULT_RE = re.compile(
    r"EMBENCH_RESULT\s+"
    r"bench=(?P<bench>\S+)\s+"
    r"status=(?P<status>\S+)\s+"
    r"cycles=(?P<cycles>\d+)\s+"
    r"instret=(?P<instret>\d+)\s+"
    r"cpi=(?P<cpi>[0-9.]+)\s+"
    r"ipc=(?P<ipc>[0-9.]+)\s+"
    r"stall_cycles=(?P<stall>\d+)\s+"
    r"flush_cycles=(?P<flush>\d+)\s+"
    r"exit_code=(?P<exit_code>-?\d+)"
)


def get_text_size(size_tool: str, elf_path: Path) -> int:
    try:
        out = subprocess.check_output([size_tool, str(elf_path)], text=True)
        lines = [line.strip() for line in out.splitlines() if line.strip()]
        if len(lines) >= 2:
            return int(lines[1].split()[0])
    except Exception:
        pass
    return 0


def run_one(
    sim_bin: Path,
    out_dir: Path,
    bench: str,
    max_cycles: int,
    size_tool: str,
) -> dict:
    mem_path = out_dir / "mem" / f"{bench}.mem"
    elf_path = out_dir / "elf" / f"{bench}.elf"
    text_bytes = get_text_size(size_tool, elf_path)

    cmd = [
        str(sim_bin),
        f"+MEM={mem_path}",
        f"+BENCH={bench}",
        f"+MAX_CYCLES={max_cycles}",
    ]

    t0 = time.monotonic()
    proc = subprocess.run(cmd, capture_output=True, text=True)
    wall_s = time.monotonic() - t0
    combined = proc.stdout + "\n" + proc.stderr

    m = RESULT_RE.search(combined)
    if not m:
        return {
            "bench": bench,
            "status": "ERROR",
            "text_bytes": text_bytes,
            "cycles": 0,
            "instret": 0,
            "cpi": 0.0,
            "ipc": 0.0,
            "stall_cycles": 0,
            "flush_cycles": 0,
            "wall_s": wall_s,
            "error": combined.strip()[-400:],
        }

    cycles = int(m.group("cycles"))
    instret = int(m.group("instret"))
    cpi = (cycles / instret) if instret > 0 else 0.0
    ipc = (instret / cycles) if cycles > 0 else 0.0
    return {
        "bench": bench,
        "status": m.group("status"),
        "text_bytes": text_bytes,
        "cycles": cycles,
        "instret": instret,
        "cpi": cpi,
        "ipc": ipc,
        "stall_cycles": int(m.group("stall")),
        "flush_cycles": int(m.group("flush")),
        "wall_s": wall_s,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Embench-IoT benchmarks on utoss-risc-v")
    parser.add_argument("--sim", required=True, type=Path, help="Path to embench_sim binary")
    parser.add_argument("--out-dir", required=True, type=Path, help="Config output dir containing elf/ and mem/")
    parser.add_argument("--isa", required=True, help="ISA configuration label")
    parser.add_argument("--max-cycles", type=int, default=200000000)
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 1)
    parser.add_argument("--size-tool", default="riscv32-unknown-elf-size")
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("benchmarks", nargs="+", help="Benchmark names to run")
    args = parser.parse_args()

    t_suite_start = time.monotonic()
    results_by_name: dict[str, dict] = {}

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        futs = {
            pool.submit(
                run_one, args.sim, args.out_dir, bench, args.max_cycles, args.size_tool
            ): bench
            for bench in args.benchmarks
        }
        for fut in concurrent.futures.as_completed(futs):
            res = fut.result()
            results_by_name[res["bench"]] = res

    ordered = [results_by_name[b] for b in args.benchmarks]
    suite_wall_s = time.monotonic() - t_suite_start

    print()
    print(f"=== UTOSS-RISC-V Embench-IoT Results ({args.isa}) ===")
    header = (
        f"{'Benchmark':<16} {'Status':<7} {'Text(B)':>8} "
        f"{'Cycles':>12} {'Instret':>12} {'CPI':>8} {'IPC':>7} "
        f"{'Stall%':>7} {'Flush%':>7} {'Wall(s)':>7}"
    )
    print(header)
    print("-" * len(header))

    passed = []
    failed = []
    for r in ordered:
        stall_pct = (100.0 * r["stall_cycles"] / r["cycles"]) if r["cycles"] > 0 else 0.0
        flush_pct = (100.0 * r["flush_cycles"] / r["cycles"]) if r["cycles"] > 0 else 0.0
        print(
            f"{r['bench']:<16} {r['status']:<7} {r['text_bytes']:>8d} "
            f"{r['cycles']:>12d} {r['instret']:>12d} {r['cpi']:>8.4f} {r['ipc']:>7.4f} "
            f"{stall_pct:>6.2f}% {flush_pct:>6.2f}% {r['wall_s']:>7.2f}"
        )
        if r["status"] == "PASS":
            passed.append(r)
        else:
            failed.append(r)
            if "error" in r:
                print(f"  -> {r['error']}")

    print("-" * len(header))
    total_cycles = sum(r["cycles"] for r in passed)
    total_instret = sum(r["instret"] for r in passed)
    total_stall = sum(r["stall_cycles"] for r in passed)
    total_flush = sum(r["flush_cycles"] for r in passed)
    agg_cpi = (total_cycles / total_instret) if total_instret > 0 else 0.0
    agg_ipc = (total_instret / total_cycles) if total_cycles > 0 else 0.0
    cpi_vals = [r["cpi"] for r in passed if r["cpi"] > 0.0]
    geo_cpi = math.exp(sum(math.log(c) for c in cpi_vals) / len(cpi_vals)) if cpi_vals else 0.0
    geo_ipc = (1.0 / geo_cpi) if geo_cpi > 0.0 else 0.0
    agg_stall_pct = (100.0 * total_stall / total_cycles) if total_cycles > 0 else 0.0
    agg_flush_pct = (100.0 * total_flush / total_cycles) if total_cycles > 0 else 0.0

    print(
        f"{'TOTAL/AGG':<16} {f'{len(passed)}/{len(ordered)}':<7} {'':>8} "
        f"{total_cycles:>12d} {total_instret:>12d} {agg_cpi:>8.4f} {agg_ipc:>7.4f} "
        f"{agg_stall_pct:>6.2f}% {agg_flush_pct:>6.2f}% {suite_wall_s:>7.2f}"
    )
    print(
        f"{'GEOMEAN':<16} {'':<7} {'':>8} "
        f"{'':>12} {'':>12} {geo_cpi:>8.4f} {geo_ipc:>7.4f}"
    )
    print()

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "isa": args.isa,
            "passed": len(passed),
            "total": len(ordered),
            "aggregate_cpi": agg_cpi,
            "aggregate_ipc": agg_ipc,
            "geomean_cpi": geo_cpi,
            "geomean_ipc": geo_ipc,
            "total_cycles": total_cycles,
            "total_instret": total_instret,
            "benchmarks": ordered,
        }
        args.json_out.write_text(json.dumps(payload, indent=2) + "\n")

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
