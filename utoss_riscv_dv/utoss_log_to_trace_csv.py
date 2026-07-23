#!/usr/bin/env python3
"""Convert UTOSS pipeline logger output to riscv-dv trace CSV."""

import argparse
import os
import re
import sys


REPO_ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
# Reuse riscv-dv's CSV writer so UTOSS emits the same column layout as Sail.
RISCV_DV_DIR = os.environ.get("RISCV_DV_DIR") or os.environ.get("RISCV_DV_HOME")
if not RISCV_DV_DIR:
    RISCV_DV_DIR = os.path.join(REPO_ROOT, "riscv-dv")
RISCV_DV_DIR = os.path.expandvars(os.path.expanduser(RISCV_DV_DIR))
sys.path.insert(0, os.path.join(RISCV_DV_DIR, "scripts"))

from riscv_trace_csv import RiscvInstructionTraceCsv, RiscvInstructionTraceEntry


WB_RE = re.compile(
    # The writeback line is the architectural register update from the pipeline.
    r"\bWB\s*:\s*(?:pc=(?P<pc>[0-9a-fA-FxX]+)\s+)?"
    r"rd=(?P<rd>[a-z0-9?]+)\((?P<rd_num>\d+)\)"
    r"\s+regwrite=1\b.*?\bwb_result=(?P<value>[0-9a-fA-F]+)"
)
FETCH_RE = re.compile(
    # IF/ID lines provide instruction context for the later writeback line.
    r"\b(?:IF|ID)\s*:\s*pc=(?P<pc>[0-9a-fA-FxX]+)\s+"
    r"instr=(?P<binary>[0-9a-fA-FxX]+)\s+op=(?P<op>[a-z0-9_?]+)"
)
MEM_RE = re.compile(
    # Store parsing is kept separate so memory lines cannot be misread as writes.
    r"\bMEM:\s*(?:pc=(?P<pc>[0-9a-fA-FxX]+)\s+)?"
    r"addr=(?P<addr>[0-9a-fA-FxX]+)\s+we=(?P<we>[01xX]+)\s+"
    r"wdata=(?P<wdata>[0-9a-fA-FxX]+)"
)


def clean_hex(value):
    # Unknown Verilog values contain x; skip them rather than producing bad CSV.
    if not value or "x" in value.lower():
        return ""
    return value.lower()


def set_if_present(entry, name, value):
    if value and hasattr(entry, name):
        setattr(entry, name, value)


def add_instruction_context(entry, pc, instruction_by_pc):
    # The comparator is more helpful when each register write has the PC and
    # instruction that produced it, not just the destination register value.
    pc = clean_hex(pc)
    set_if_present(entry, "pc", pc)
    set_if_present(entry, "instr_addr", pc)

    context = instruction_by_pc.get(pc, {})
    binary = clean_hex(context.get("binary", ""))
    op = context.get("op", "")
    set_if_present(entry, "binary", binary)
    set_if_present(entry, "instr_bin", binary)
    set_if_present(entry, "instr_str", op)


def process_utoss_sim_log(log, csv):
    with open(log, "r", errors="replace") as log_fd, open(csv, "w") as csv_fd:
        trace_csv = RiscvInstructionTraceCsv(csv_fd)
        trace_csv.start_new_trace()
        instruction_by_pc = {}

        for line in log_fd:
            # The tohost write is the generated program's "test complete" signal.
            if "memory[tohost] written" in line:
                break

            # Cache instruction context by PC as it flows through the front end.
            fetch_match = FETCH_RE.search(line)
            if fetch_match:
                pc = clean_hex(fetch_match.group("pc"))
                if pc:
                    instruction_by_pc[pc] = {
                        "binary": fetch_match.group("binary"),
                        "op": fetch_match.group("op"),
                    }
                continue

            mem_match = MEM_RE.search(line)
            if mem_match and "1" in mem_match.group("we"):
                # Parsed here so store lines do not get mistaken for writeback lines.
                # Do not emit them yet; first confirm the Sail converter emits matching store rows.
                continue

            match = WB_RE.search(line)
            if not match:
                continue

            # Keep zero-valued writes so row order stays aligned with Sail.
            rd = match.group("rd")
            rd_num = int(match.group("rd_num"))
            value = match.group("value").lower()
            if rd_num == 0 or "x" in value:
                continue

            entry = RiscvInstructionTraceEntry()
            add_instruction_context(entry, match.group("pc") or "", instruction_by_pc)
            entry.gpr.append(f"{rd}:{value}")
            trace_csv.write_trace_entry(entry)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True)
    parser.add_argument("--csv", required=True)
    args = parser.parse_args()
    process_utoss_sim_log(args.log, args.csv)


if __name__ == "__main__":
    main()
