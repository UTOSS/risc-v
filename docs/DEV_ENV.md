# Dev Environment Guide

> **Goal:** get new contributors running simulations and tests for this SystemVerilog RISC‑V core on Linux/macOS (Icarus Verilog), Windows via WSL2, or native Windows using ModelSim‑Intel (Quartus) or Vivado XSIM. Pick one path and you'll be able to compile and run any testbench in `test/` against sources in `src/`.

---

## TL;DR (choose one)

| Platform                      | Simulator                | Install (one‑liner-ish)                                        | Run example bench                                            |
| ----------------------------- | ------------------------ | -------------------------------------------------------------- | ------------------------------------------------------------ |
| **Linux (Ubuntu/Debian)**     | Icarus Verilog           | `sudo apt update && sudo apt install -y iverilog gtkwave make` | `./tools/icarus_run.sh test/<your_tb>.sv`                    |
| **macOS (Homebrew)**          | Icarus Verilog           | `brew install icarus-verilog gtkwave gnu-sed make`             | `./tools/icarus_run.sh test/<your_tb>.sv`                    |
| **Windows via WSL2 (Ubuntu)** | Icarus Verilog           | `wsl --install -d Ubuntu` → then same as Linux                 | `./tools/icarus_run.sh test/<your_tb>.sv`                    |
| **Windows (native)**          | ModelSim‑Intel (Quartus) | Install Quartus + ModelSim‑Intel (Starter OK)                  | `vsim -do scripts/msim_run.do TB=<your_tb_module>`           |
| **Windows (native)**          | Vivado XSIM              | Install Vivado (WebPACK OK)                                    | `powershell -File scripts/xsim_run.ps1 -Tb <your_tb_module>` |

> **Examples of `<your_tb>`**: any `*_tb.sv` inside `test/` (e.g., `test/srli_tb.sv`). **Examples of `<your_tb_module>`**: the top module name inside that file (e.g., `srli_tb`).

---

## Repository layout (assumed)

```
src/                # RTL and core components
include/            # (optional) shared headers / packages
test/               # self‑checking testbenches (one DUT per file)
scripts/            # helper scripts for simulators (added in this PR)
tools/              # tiny wrappers for common flows (added in this PR)
build/              # generated outputs (ignored)
```

> If your local clone is missing `scripts/` or `tools/`, copy them from this doc's snippets below.

---

## 1) Linux (Ubuntu/Debian) with Icarus Verilog

```bash
sudo apt update && sudo apt install -y iverilog gtkwave make
iverilog -v          # should print version >= 11 and `-g2012` support
```

**Run a testbench (direct commands):**

```bash
mkdir -p build
# Example with SRLI testbench; replace with the bench you want
iverilog -g2012 -Wall \
  -I include -I src -I test \
  -o build/srli_tb.vvp \
  $(find src -name '*.sv' -o -name '*.v') test/srli_tb.sv
vvp build/srli_tb.vvp
```

**Optional VCD waves:** if a TB contains `$dumpfile/$dumpvars`, open it with `gtkwave build/wave.vcd`.

**Convenience wrapper (recommended):** put this into `tools/icarus_run.sh` (make it executable):

```bash
#!/usr/bin/env bash
set -euo pipefail
TB_FILE=${1:-}
if [[ -z ${TB_FILE} ]]; then
  echo "Usage: tools/icarus_run.sh test/<tb_file>.sv"; exit 2
fi
mkdir -p build
OUT=build/$(basename "$TB_FILE" .sv).vvp
iverilog -g2012 -Wall -I include -I src -I test -o "$OUT" \
  $(find src -type f -name '*.sv' -o -name '*.v') "$TB_FILE"
vvp "$OUT"
```

Run it:

```bash
chmod +x tools/icarus_run.sh
./tools/icarus_run.sh test/srli_tb.sv
```

---

## 2) macOS (Homebrew) with Icarus Verilog

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" # if needed
brew install icarus-verilog gtkwave gnu-sed make
iverilog -v
```

Use the same `tools/icarus_run.sh` script as on Linux.

> On Apple Silicon, Homebrew's Icarus is arm64; it works fine. If you hit plugin path issues with GTKWave, run it via `open -a GTKWave build/wave.vcd`.

---

## 3) Windows via WSL2 (recommended for Windows)

1. Open **PowerShell as Administrator** and run: `wsl --install -d Ubuntu`.
2. Reboot when prompted and complete Ubuntu setup.
3. In Ubuntu terminal, follow **Linux** steps (`apt install iverilog gtkwave make`).
4. Use the same `tools/icarus_run.sh` flow. Your repo is best cloned **inside** WSL (`~/work/risc-v`).

> To view VCDs, either install `gtkwave` inside WSL and use an X server (VcXsrv) or copy `build/*.vcd` to Windows and open with a Windows GTKWave build.

---

## 4) Native Windows — ModelSim‑Intel (Quartus)

**Install:** Quartus includes ModelSim‑Intel (Starter Edition is fine for simulation). During install, check the ModelSim component.

**Scripted run:** Create `scripts/msim_run.do`:

```tcl
# scripts/msim_run.do — run a SystemVerilog testbench in ModelSim
# Usage: vsim -do scripts/msim_run.do TB=srli_tb
if {![info exists TB]} {
  puts "ERROR: pass TB=<top_tb_module>"; quit -code 2
}
vlib work
vmap work work
# Compile sources (adjust globbing if your shell doesn't expand **)
vlog -sv +incdir+include +incdir+src +incdir+test \
  src/**/*.sv src/**/*.v test/${TB}.sv
# Run headless
vsim -c work.${TB} -do "run -all; quit"
```

Run from a **ModelSim command prompt**:

```bat
vsim -do scripts\msim_run.do TB=srli_tb
```

> If `**` globbing fails, list files explicitly or generate a `filelist.f` (many users prefer this). You can export one from the Icarus wrapper by echoing the expanded list.

---

## 5) Native Windows — Vivado XSIM

**Scripted run (PowerShell):** Create `scripts/xsim_run.ps1`:

```powershell
param(
  [Parameter(Mandatory=$true)][string]$Tb
)
New-Item -Force -ItemType Directory build | Out-Null
# Compile
xvlog --sv $(Get-ChildItem -Recurse src -Include *.sv,*.v | ForEach-Object { $_.FullName }) test/$Tb.sv
# Elaborate
xelab -debug typical $Tb -s $Tb
echo "Running $Tb..."
xsim -R $Tb
```

Run from a **Vivado Tcl Console** or **VS Tools for Xilinx** shell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\xsim_run.ps1 -Tb srli_tb
```

---

## 6) Adding a new testbench

1. Create `test/<name>_tb.sv` with a clear top module (e.g., `module <name>_tb;`).
2. Keep benches **self‑checking**: use `$fatal`/`$error` on mismatches and end with `$finish;`.
3. Prefer short, fast benches; CI should complete quickly.

**Minimal template:**

```systemverilog
`timescale 1ns/1ps
module example_tb;
  // DUT
  // example_dut dut(.clk(clk), .rstn(rstn), /* ... */);

  // Clock/reset
  logic clk = 0; always #5 clk = ~clk; // 100 MHz
  logic rstn = 0; initial begin rstn = 0; repeat (5) @(posedge clk); rstn = 1; end

  // Test sequence
  initial begin
    // TODO: drive inputs, wait for outputs, assert expectations
    $display("[TB] starting");
    // ...
    $display("[TB] PASS");
    $finish;
  end

  // Optional VCD
  initial begin
    if ($test$plusargs("vcd")) begin
      $dumpfile("build/wave.vcd");
      $dumpvars(0, example_tb);
    end
  end
endmodule
```

Run with VCD enabled via `+vcd` plusarg where supported.

---

## 7) Troubleshooting

* **`syntax error, unexpected TOK_*` in Icarus** → Add `-g2012` and ensure files are `.sv` for SystemVerilog.
* **Include/path errors** → Add `-I include -I src -I test` (or the dirs you actually use).
* **ModelSim cannot find top `work.<tb>`** → Ensure `TB=<module_name>` matches the *module* inside your TB file.
* **Wildcards don't expand on Windows** → Replace `src/**/*.sv` with an explicit file list or use a `filelist.f`.
* **No VCD output** → Confirm your TB calls `$dumpfile/$dumpvars`, or use simulator‑specific flags to enable dumps.

---

## 8) Contributing workflow

1. **Fork** the repo and create a branch: `git checkout -b docs/dev-env`.
2. Add this file as `docs/DEV_ENV.md` and the helper scripts under `scripts/` and `tools/` if you use them.
3. Update `README.md` with a short link to this guide.
4. Run one simulator path locally to validate.
5. Open a PR with: a short description, simulator and OS tested, and a console transcript or screenshot.

**Pre‑PR checklist**

* [ ] I can compile and run at least one TB locally.
* [ ] Added/updated docs and helper scripts.
* [ ] Kept paths portable; no absolute paths.
* [ ] CI (if any) still passes.

---

## 9) Appendix: file lists (optional)

Some teams prefer a `filelist.f` consumed by all simulators. Example format:

```
+incdir+include
+incdir+src
+incdir+test
src/core/top.sv
src/core/alu.sv
# ...
test/srli_tb.sv
```

**Icarus:** `iverilog -g2012 -f filelist.f -o build/tb.vvp`

**ModelSim:** `vlog -sv -f filelist.f` then `vsim -c work.srli_tb -do "run -all; quit"`

**XSIM:** `xvlog --sv -f filelist.f` then `xelab -debug typical srli_tb -s srli_tb && xsim -R srli_tb`
