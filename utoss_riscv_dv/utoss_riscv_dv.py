#!/usr/bin/env python3
"""Generate a riscv-dv test, run it on UTOSS, and compare against Sail."""

import argparse
import csv
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def cmd(args, cwd, stdout=None, timeout=None, log_path=None, env=None):
    # Print every external command so a failing run can be replayed by hand.
    print("+ " + " ".join(str(arg) for arg in args))
    try:
        subprocess.run(
            args,
            cwd=cwd,
            stdout=stdout,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=True,
            env=env,
        )
    except subprocess.CalledProcessError as error:
        print(f"\nCommand failed with exit code {error.returncode}.")
        if log_path:
            print(f"Log: {log_path}")
            print("\n".join(read(log_path).splitlines()[-40:]))
        raise SystemExit(error.returncode)


def read(path):
    return path.read_text(errors="replace") if path.exists() else ""


def find_symbol(nm, elf, symbol, cwd):
    # The simulator watches the generated program's tohost symbol to know when to stop.
    result = subprocess.run([nm, str(elf)], cwd=cwd, text=True, stdout=subprocess.PIPE, check=True)
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[2] == symbol:
            return parts[0]
    return ""


def gpr_update(row):
    text = row.get("gpr", "")
    if ":" not in text or ";" in text:
        return None, None
    reg, value = text.split(":", 1)
    try:
        return reg, int(value, 16)
    except ValueError:
        return None, None


def hex_update(row, field):
    value = row.get(field, "")
    if not value:
        return None
    try:
        return int(value, 16)
    except ValueError:
        return None


def changed_gprs(rows):
    # riscv-dv trace CSVs can contain repeated writes of the same value.
    # Only state-changing writes are useful for aligning Sail and UTOSS address values.
    state = {}
    changes = []
    for index, row in enumerate(rows):
        reg, value = gpr_update(row)
        if reg is None:
            continue
        if state.get(reg, 0) != value:
            changes.append((index, reg, value))
        state[reg] = value
    return changes


def set_default(env, name, value):
    if not env.get(name):
        env[name] = value


def expand_path(path):
    return Path(os.path.expandvars(os.path.expanduser(str(path))))


def write_sail_iss_yaml(directory):
    # Upstream riscv-dv expects riscv_ocaml_sim_RV32/64, while some Sail installs
    # provide riscv_sim_RV32/64. This temporary YAML keeps Sail execution inside
    # riscv-dv's normal iss_sim step while accepting either binary name.
    path = Path(directory) / "iss.yaml"
    path.write_text(
        "- iss: sail\n"
        "  path_var: SAIL_RISCV\n"
        "  cmd: >\n"
        "    bash -lc 'if [ -x \"<path_var>/riscv_ocaml_sim_RV<xlen>\" ]; then "
        "exec \"<path_var>/riscv_ocaml_sim_RV<xlen>\" \"$1\"; "
        "else exec \"<path_var>/riscv_sim_RV<xlen>\" \"$1\"; fi' _ <elf>\n"
    )
    return path


def path_arg(path, root):
    # Use short repo-relative paths when possible, but allow riscv-dv outputs to
    # live outside the repo when RISCV_DV_HOME points to an external checkout.
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def normalize_address_values(sail_csv, utoss_csv, normalized_csv, offset, isa):
    # Sail normally runs RISC-V tests at 0x80000000, while this core currently
    # runs the same memory image at 0x0. Normalize address-like trace values so
    # PC-relative instructions do not fail only because of that base difference.
    if offset == 0:
        return utoss_csv, 0

    with open(sail_csv, newline="") as sail_fd, open(utoss_csv, newline="") as utoss_fd:
        sail_rows = list(csv.DictReader(sail_fd))
        utoss_reader = csv.DictReader(utoss_fd)
        utoss_rows = list(utoss_reader)

    mask = (1 << 64) - 1 if isa.lower().startswith("rv64") else (1 << 32) - 1
    width = 16 if isa.lower().startswith("rv64") else 8
    count = 0

    for (_, sail_reg, sail_value), (utoss_index, utoss_reg, utoss_value) in zip(
        changed_gprs(sail_rows),
        changed_gprs(utoss_rows),
    ):
        if sail_reg == utoss_reg and ((sail_value - offset) & mask) == utoss_value:
            utoss_rows[utoss_index]["gpr"] = f"{utoss_reg}:{sail_value:0{width}x}"
            count += 1

    for sail_row, utoss_row in zip(sail_rows, utoss_rows):
        for field in ("pc", "instr_addr"):
            sail_value = hex_update(sail_row, field)
            utoss_value = hex_update(utoss_row, field)
            if sail_value is not None and utoss_value is not None and ((sail_value - offset) & mask) == utoss_value:
                utoss_row[field] = f"{sail_value:0{width}x}"

    with open(normalized_csv, "w", newline="") as csv_fd:
        writer = csv.DictWriter(csv_fd, fieldnames=utoss_reader.fieldnames)
        writer.writeheader()
        writer.writerows(utoss_rows)
    return normalized_csv, count


def main():
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=script_dir.parent)
    parser.add_argument("--riscv-dv-dir", type=Path, default=Path(os.environ.get("RISCV_DV_HOME", "~/tools/riscv-dv")))
    parser.add_argument("--output", "-o", default="utoss_riscv_dv/logs/out_utoss_smoke")
    parser.add_argument("--test", default="utoss_rv32i_arithmetic_smoke")
    parser.add_argument("--testlist", default="utoss_riscv_dv/utoss_riscv_dv_smoke.yaml")
    parser.add_argument("--target", default="rv32i")
    parser.add_argument("--simulator", default="pyflow")
    parser.add_argument("--isa", default="rv32i_zicsr")
    parser.add_argument("--mabi", default="ilp32")
    parser.add_argument("--iteration", type=int, default=0)
    parser.add_argument("--iss", default="sail")
    parser.add_argument("--seed")
    parser.add_argument("--skip-dut", action="store_true")
    parser.add_argument("--iss-timeout-sec", type=int, default=60)
    parser.add_argument("--dut-timeout-sec", type=int, default=60)
    parser.add_argument("--trace-address-offset", default="0x80000000")
    args, extra_riscv_dv_args = parser.parse_known_args()

    root = expand_path(args.repo_root).resolve()
    riscv_dv_path = expand_path(args.riscv_dv_dir)
    riscv_dv = (riscv_dv_path if riscv_dv_path.is_absolute() else root / riscv_dv_path).resolve()
    if not (riscv_dv / "run.py").exists():
        print(f"Could not find riscv-dv run.py under: {riscv_dv}")
        print("Set RISCV_DV_HOME or pass RISCV_DV_DIR=/path/to/riscv-dv.")
        return 1

    testlist = expand_path(args.testlist)
    if not testlist.is_absolute() and (root / testlist).exists():
        testlist = (root / testlist).resolve()
    output_path = expand_path(args.output)
    out = (output_path if output_path.is_absolute() else root / output_path).resolve()
    test = f"{args.test}_{args.iteration}"
    asm = out / "asm_test" / f"{test}.S"
    elf = out / "asm_test" / f"{test}.dut.elf"
    mem = out / "asm_test" / f"{test}.mem"
    sail_log = out / f"{args.iss}_sim" / f"{test}.log"
    utoss_log = out / "dut.log"
    sail_csv = out / f"{test}.sail.csv"
    utoss_csv = out / f"{test}.utoss.csv"
    normalized_csv = out / f"{test}.utoss.normalized.csv"
    compare_log = out / "trace_compare.log"
    riscv_dv_log = out / "riscv_dv_run.log"

    env = os.environ.copy()
    # riscv-dv reads these tool paths from the environment. Set defaults so the
    # Makefile target works without requiring every variable to be exported.
    env["RISCV_DV_DIR"] = str(riscv_dv)
    set_default(env, "RISCV_GCC", "/opt/riscv/bin/riscv32-unknown-elf-gcc")
    set_default(env, "RISCV_OBJCOPY", "/opt/riscv/bin/riscv32-unknown-elf-objcopy")
    set_default(env, "RISCV_NM", "/opt/riscv/bin/riscv32-unknown-elf-nm")
    if args.iss == "sail":
        set_default(env, "SAIL_RISCV", "/usr/local/bin")
    gcc = env["RISCV_GCC"]
    objcopy = env["RISCV_OBJCOPY"]
    nm = env["RISCV_NM"]

    run_py = [
        sys.executable,
        "run.py",
        "--testlist", str(testlist),
        "--test", args.test,
        "--target", args.target,
        "--simulator", args.simulator,
        "--iss", args.iss,
        "--steps", "gen,gcc_compile,iss_sim",
        "--iss_timeout", str(args.iss_timeout_sec),
        "--isa", args.isa,
        "--mabi", args.mabi,
        "-o", str(out),
    ]
    if args.seed:
        run_py += ["--seed", args.seed]
    out.mkdir(parents=True, exist_ok=True)
    # Let riscv-dv do the generation, GCC compile, and Sail reference run.
    custom_iss_yaml = any(arg == "--iss_yaml" or arg.startswith("--iss_yaml=") for arg in extra_riscv_dv_args)
    temp_dir = tempfile.TemporaryDirectory(prefix="utoss_riscv_dv_") if args.iss == "sail" and not custom_iss_yaml else None
    try:
        if temp_dir:
            run_py += ["--iss_yaml", str(write_sail_iss_yaml(temp_dir.name))]
        with riscv_dv_log.open("w") as log:
            cmd(run_py + extra_riscv_dv_args, riscv_dv, stdout=log, log_path=riscv_dv_log, env=env)
    finally:
        if temp_dir:
            temp_dir.cleanup()

    # Recompile the same assembly with the UTOSS/RISCOF linker script and turn it
    # into the Verilog memory image consumed by the processor simulator.
    cmd([
        gcc,
        f"-march={args.isa}",
        f"-mabi={args.mabi}",
        "-mno-relax",
        "-static",
        "-mcmodel=medany",
        "-fvisibility=hidden",
        "-nostdlib",
        "-nostartfiles",
        "-I", str(riscv_dv / "user_extension"),
        "-T", "riscof/utoss_riscv/env/link.ld",
        "-Wl,-e,_start",
        str(asm),
        "-o", str(elf),
    ], root, env=env)
    cmd([objcopy, "-O", "verilog", "--verilog-data-width=4", str(elf), str(mem)], root, env=env)

    if args.skip_dut:
        print(f"Sail log written to {sail_log}")
        return 0

    tohost = find_symbol(nm, elf, "tohost", root)
    if not tohost:
        print(f"No tohost symbol found in {elf}; the simulator needs it to stop.")
        return 1

    # Run the UTOSS Verilator simulator on the generated memory image.
    cmd(["make", "riscof_build_dut"], root, env=env)
    try:
        with utoss_log.open("w") as log:
            cmd([
                "./riscof/dut_sim",
                f"+MEM={path_arg(mem, root)}",
                f"+tohost={tohost}",
                f"+VCD_PATH={path_arg(out, root)}",
            ], root, stdout=log, timeout=args.dut_timeout_sec, log_path=utoss_log, env=env)
    except subprocess.TimeoutExpired:
        print(f"UTOSS simulation timed out after {args.dut_timeout_sec}s; see {utoss_log}")
        return 1

    # Convert both logs to riscv-dv trace CSVs, normalize address-base differences,
    # and use riscv-dv's comparator for the final pass/fail decision.
    compare_log.unlink(missing_ok=True)
    cmd([sys.executable, str(riscv_dv / "scripts" / "sail_log_to_trace_csv.py"), "--log", str(sail_log), "--csv", str(sail_csv)], root, env=env)
    cmd([sys.executable, str(root / "utoss_riscv_dv" / "utoss_log_to_trace_csv.py"), "--log", str(utoss_log), "--csv", str(utoss_csv)], root, env=env)
    compare_csv, normalized = normalize_address_values(
        sail_csv,
        utoss_csv,
        normalized_csv,
        int(args.trace_address_offset, 0),
        args.isa,
    )
    cmd([
        sys.executable,
        str(riscv_dv / "scripts" / "instr_trace_compare.py"),
        "--csv_file_1", str(sail_csv),
        "--csv_file_2", str(compare_csv),
        "--csv_name_1", "sail",
        "--csv_name_2", "utoss",
        "--log", str(compare_log),
    ], root, env=env)

    sail_ok = "SUCCESS" in read(sail_log)
    utoss_ok = "memory[tohost] written <1>" in read(utoss_log)
    trace_ok = "[PASSED]" in read(compare_log)

    print("\nriscv-dv result")
    print(f"  Sail : {'PASS' if sail_ok else 'FAIL'} ({sail_log})")
    print(f"  UTOSS: {'PASS' if utoss_ok else 'FAIL'} ({utoss_log})")
    print(f"  Trace: {'PASS' if trace_ok else 'FAIL'} ({compare_log})")
    print(f"    Sail CSV : {sail_csv}")
    print(f"    UTOSS CSV: {utoss_csv}")
    if compare_csv != utoss_csv:
        print(f"    Compare CSV: {compare_csv}")
        print(f"    normalized {normalized} address-offset update(s)")

    passed = sail_ok and utoss_ok and trace_ok
    print(f"VERDICT: {'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
