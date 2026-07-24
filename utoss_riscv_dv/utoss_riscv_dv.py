#!/usr/bin/env python3
"""Generate a riscv-dv test, run it on UTOSS, and compare against Sail."""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def expand_path(path):
    return Path(os.path.expandvars(os.path.expanduser(str(path))))


def riscv_target_parts(name):
    name = name.lower().replace("_", "")
    extensions = set(name[4:])
    if "g" in extensions:
        extensions.remove("g")
        extensions.update("imafd")
    return name[:4], extensions


def choose_riscv_dv_target(config, riscv_dv):
    config_base, config_extensions = riscv_target_parts(config)
    candidates = []
    for target in (riscv_dv / "pygen" / "pygen_src" / "target").iterdir():
        if not target.is_dir() or not target.name.lower().startswith(config_base):
            continue
        target_base, target_extensions = riscv_target_parts(target.name)
        if target_base == config_base and target_extensions <= config_extensions:
            if target.name == "rv32imcb": # This target is currently broken
                continue
            candidates.append((len(target_extensions), target.name))
    return max(candidates)[1]


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
    parser.add_argument("--isa", default="")
    parser.add_argument("--mabi", default="ilp32")
    parser.add_argument("--iss", default="sail")
    parser.add_argument("--seed")
    parser.add_argument("--gen-timeout", type=int)
    parser.add_argument("--skip-dut", action="store_true")
    args, extra_riscv_dv_args = parser.parse_known_args()

    root = expand_path(args.repo_root).resolve()
    riscv_dv_path = expand_path(args.riscv_dv_dir)
    riscv_dv = (riscv_dv_path if riscv_dv_path.is_absolute() else root / riscv_dv_path).resolve()
    if not (riscv_dv / "run.py").exists():
        print(f"Could not find riscv-dv run.py under: {riscv_dv}")
        print("Set RISCV_DV_HOME or pass RISCV_DV_DIR=/path/to/riscv-dv.")
        return 1

    target = choose_riscv_dv_target(args.target, riscv_dv)
    if target != args.target:
        print(f"Target {args.target} is not available. Defaulting to riscv-dv target {target}.\n")

    testlist = expand_path(args.testlist)
    if not testlist.is_absolute() and (root / testlist).exists():
        testlist = (root / testlist).resolve()
    output_path = expand_path(args.output)
    out = (output_path if output_path.is_absolute() else root / output_path).resolve()
    test = args.test
    riscv_dv_test = f"{test}_0"
    asm = out / "asm_test" / f"{riscv_dv_test}.S"
    elf = out / "asm_test" / f"{test}.dut.elf"
    mem = out / "asm_test" / f"{test}.mem"
    sail_log = out / f"{args.iss}_sim" / f"{riscv_dv_test}.log"
    utoss_log = out / "dut.log"
    sail_csv = out / f"{test}.sail.csv"
    compare_csv = out / f"{test}.utoss.csv"
    compare_log = out / "trace_compare.log"
    riscv_dv_log = out / "riscv_dv_run.log"

    env = os.environ.copy()
    # riscv-dv reads these tool paths from the environment. Set defaults so the
    # Makefile target works without requiring every variable to be exported.
    env["RISCV_DV_DIR"] = str(riscv_dv)
    env["RISCV_GCC"] = env.get("RISCV_GCC") or "/opt/riscv/bin/riscv32-unknown-elf-gcc"
    env["RISCV_OBJCOPY"] = env.get("RISCV_OBJCOPY") or "/opt/riscv/bin/riscv32-unknown-elf-objcopy"
    env["RISCV_NM"] = env.get("RISCV_NM") or "/opt/riscv/bin/riscv32-unknown-elf-nm"
    if args.iss == "sail":
        env["SAIL_RISCV"] = env.get("SAIL_RISCV") or "/usr/local/bin"
    gcc = env["RISCV_GCC"]
    objcopy = env["RISCV_OBJCOPY"]
    nm = env["RISCV_NM"]

    run_py = [
        sys.executable,
        "run.py",
        "--testlist", str(testlist),
        "--test", args.test,
        "--target", target,
        "--simulator", args.simulator,
        "--iss", args.iss,
        "--steps", "gen,gcc_compile,iss_sim",
        "--isa", args.isa,
        "--mabi", args.mabi,
        "-o", str(out),
    ]
    if args.seed:
        run_py += ["--seed", args.seed]
    if args.gen_timeout:
        run_py += ["--gen_timeout", str(args.gen_timeout)]
    if args.iss == "sail":
        run_py += ["--iss_yaml", str(script_dir / "sail_iss.yaml")]
    out.mkdir(parents=True, exist_ok=True)
    # Let riscv-dv do the generation, GCC compile, and Sail reference run.
    with riscv_dv_log.open("w") as log:
        command = run_py + extra_riscv_dv_args
        print("+ " + " ".join(str(arg) for arg in command))
        result = subprocess.run(command, cwd=riscv_dv, stdout=log, stderr=subprocess.STDOUT, env=env)
    if result.returncode:
        print(f"\nCommand failed with exit code {result.returncode}.")
        print(f"Log: {riscv_dv_log}")
        return result.returncode

    # Recompile the same assembly with the UTOSS/RISCOF linker script and turn it
    # into the Verilog memory image consumed by the processor simulator.
    command = [
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
        "-T", "utoss_riscv_dv/env/link.ld",
        "-Wl,-e,_start",
        str(asm),
        "-o", str(elf),
    ]
    print("+ " + " ".join(str(arg) for arg in command))
    subprocess.run(command, cwd=root, check=True, env=env)

    command = [objcopy, "-O", "verilog", "--verilog-data-width=4", "--change-addresses=-0x80000000", str(elf), str(mem)]
    print("+ " + " ".join(str(arg) for arg in command))
    subprocess.run(command, cwd=root, check=True, env=env)

    if args.skip_dut:
        print(f"Sail log written to {sail_log}")
        return 0

    # The simulator watches the generated program's tohost symbol to know when to stop.
    result = subprocess.run([nm, str(elf)], cwd=root, text=True, stdout=subprocess.PIPE, check=True)
    tohost = ""
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[2] == "tohost":
            tohost = parts[0]
            break
    if not tohost:
        print(f"No tohost symbol found in {elf}; the simulator needs it to stop.")
        return 1

    # Run the UTOSS Verilator simulator on the generated memory image.
    command = ["make", "-B", "riscof_build_dut"]
    env["UTOSS_BOOT_ADDR"] = "32\\'h8000_0000"

    print("+ " + " ".join(str(arg) for arg in command))
    subprocess.run(command, cwd=root, check=True, env=env)
    with utoss_log.open("w") as log:
        command = [
            "./riscof/dut_sim",
            f"+MEM={mem.as_posix()}",
            f"+tohost={tohost}",
            f"+VCD_PATH={out.as_posix()}",
        ]
        print("+ " + " ".join(str(arg) for arg in command))
        result = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, env=env)
    if result.returncode:
        print(f"\nCommand failed with exit code {result.returncode}.")
        print(f"Log: {utoss_log}")
        return result.returncode

    # Convert both logs to riscv-dv trace CSVs and use riscv-dv's comparator for
    # the final pass/fail decision.
    compare_log.unlink(missing_ok=True)
    command = [sys.executable, str(riscv_dv / "scripts" / "sail_log_to_trace_csv.py"), "--log", str(sail_log), "--csv", str(sail_csv)]
    print("+ " + " ".join(str(arg) for arg in command))
    subprocess.run(command, cwd=root, check=True, env=env)

    command = [sys.executable, str(root / "utoss_riscv_dv" / "utoss_log_to_trace_csv.py"), "--log", str(utoss_log), "--csv", str(compare_csv)]
    print("+ " + " ".join(str(arg) for arg in command))
    subprocess.run(command, cwd=root, check=True, env=env)
    command = [
        sys.executable,
        str(riscv_dv / "scripts" / "instr_trace_compare.py"),
        "--csv_file_1", str(sail_csv),
        "--csv_file_2", str(compare_csv),
        "--csv_name_1", "sail",
        "--csv_name_2", "utoss",
        "--log", str(compare_log),
    ]
    print("+ " + " ".join(str(arg) for arg in command))
    subprocess.run(command, cwd=root, check=True, env=env)

    sail_text = sail_log.read_text(errors="replace") if sail_log.exists() else ""
    utoss_text = utoss_log.read_text(errors="replace") if utoss_log.exists() else ""
    compare_text = compare_log.read_text(errors="replace") if compare_log.exists() else ""
    sail_ok = "SUCCESS" in sail_text
    utoss_ok = "memory[tohost] written <1>" in utoss_text
    trace_ok = "[PASSED]" in compare_text

    print("\nriscv-dv result")
    print(f"  Sail : {'PASS' if sail_ok else 'FAIL'} ({sail_log})")
    print(f"  UTOSS: {'PASS' if utoss_ok else 'FAIL'} ({utoss_log})")
    print(f"  Trace: {'PASS' if trace_ok else 'FAIL'} ({compare_log})")
    print(f"    Sail CSV : {sail_csv}")
    print(f"    UTOSS CSV: {compare_csv}")

    passed = sail_ok and utoss_ok and trace_ok
    print(f"VERDICT: {'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        print(f"\nCommand failed with exit code {error.returncode}.")
        raise SystemExit(error.returncode)
