#!/usr/bin/env python3
"""Prepare and filter test_list.yaml for RISCOF execution."""

import argparse
import os
import pathlib
import shutil
import yaml


def main():
    script_dir = pathlib.Path(__file__).resolve().parent
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config", default="RV32I", help="UTOSS_RISCV_CONFIG"
    )
    parser.add_argument(
        "--work-dir",
        default=str((script_dir.parent / "riscof_work").resolve()),
        help="Path to riscof_work directory",
    )
    parser.add_argument(
        "--zicsr-test",
        default=str((script_dir / "zicsr.S").resolve()),
        help="Path to zicsr.S",
    )
    args = parser.parse_args()

    work_dir = pathlib.Path(args.work_dir)
    test_list_path = work_dir / "test_list.yaml"
    if not test_list_path.exists():
        print(f"Error: {test_list_path} does not exist.")
        return 1

    with open(test_list_path, "r") as f:
        tests = yaml.safe_load(f)

    is_zicsr = "zicsr" in args.config.lower()
    new_tests = {}

    for path, test in tests.items():
        # In arch-test, pmp and privilege suites require full trap
        # handling/PMP, which neither UTOSS nor standard unprivileged Zicsr
        # target supports, and triggers infinite loops in Sail for PMP tests.
        # Hints tests in upstream arch-test are non-standard.
        if is_zicsr and any(
            x in path for x in ("/pmp/", "/privilege/", "/hints/")
        ):
            continue
        new_tests[path] = test

    if is_zicsr:
        zicsr_s = os.path.abspath(args.zicsr_test)
        if os.path.exists(zicsr_s):
            new_tests[zicsr_s] = {
                "commit_id": "1.0",
                "work_dir": str(
                    (work_dir / "utoss_riscv" / "zicsr.S").resolve()
                ),
                "macros": ["XLEN=32"],
                "isa": args.config,
                "coverage_labels": [],
                "test_path": zicsr_s,
            }

    # Ensure all test work directories exist and have clean subdirectories
    for path, test in new_tests.items():
        t_work_dir = pathlib.Path(test["work_dir"])
        dut_dir = t_work_dir / "dut"
        ref_dir = t_work_dir / "ref"
        if dut_dir.exists():
            shutil.rmtree(dut_dir)
        if ref_dir.exists():
            shutil.rmtree(ref_dir)
        t_work_dir.mkdir(parents=True, exist_ok=True)

    with open(test_list_path, "w") as f:
        yaml.dump(new_tests, f)

    print(
        f"Prepared {len(new_tests)} tests for RISCOF "
        f"(config={args.config}, is_zicsr={is_zicsr})"
    )
    return 0


if __name__ == "__main__":
    main()
