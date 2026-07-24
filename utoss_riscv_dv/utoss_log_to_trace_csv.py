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
ID_RE = re.compile(
    r"\bID\s*:\s*pc=(?P<pc>[0-9a-fA-FxX]+)\s+"
    r"instr=(?P<binary>[0-9a-fA-FxX]+)\s+op=(?P<op>[a-z0-9_?]+)\s+"
    r"rs1=(?P<rs1>[a-z0-9?]+)\s+rs2=(?P<rs2>[a-z0-9?]+)\s+"
    r"rd=(?P<rd>[a-z0-9?]+)\s+imm=(?P<imm>[0-9a-fA-FxX]+)"
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
    set_if_present(entry, "instr", op)

    operand = context.get("operand", "")
    set_if_present(entry, "operand", operand)


def add_instruction_context_from_line(instruction_by_pc, match):
    pc = clean_hex(match.group("pc"))
    if pc:
        context = instruction_by_pc.setdefault(pc, {})
        context["binary"] = match.group("binary")
        context["op"] = match.group("op")


def add_id_context(instruction_by_pc, match):
    add_instruction_context_from_line(instruction_by_pc, match)
    pc = clean_hex(match.group("pc"))
    if pc:
        context = instruction_by_pc.setdefault(pc, {})
        context["rs1"] = match.group("rs1")
        context["rs2"] = match.group("rs2")
        context["rd"] = match.group("rd")
        context["imm"] = clean_hex(match.group("imm"))

        if context.get("op", "").startswith("s"):
            context["operand"] = "{},{},{}".format(
                context["rs2"],
                context["rs1"],
                context["imm"],
            )


def write_store_entry(trace_csv, mem_match, instruction_by_pc):
    entry = RiscvInstructionTraceEntry()
    add_instruction_context(entry, mem_match.group("pc") or "", instruction_by_pc)
    trace_csv.write_trace_entry(entry)


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
            id_match = ID_RE.search(line)
            if id_match:
                add_id_context(instruction_by_pc, id_match)
                continue

            fetch_match = FETCH_RE.search(line)
            if fetch_match:
                add_instruction_context_from_line(instruction_by_pc, fetch_match)
                continue

            mem_match = MEM_RE.search(line)
            if mem_match and "1" in mem_match.group("we"):
                # Store rows do not affect riscv-dv's default GPR comparison, but
                # keeping them in the CSV makes the memory side of the trace visible.
                write_store_entry(trace_csv, mem_match, instruction_by_pc)
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
