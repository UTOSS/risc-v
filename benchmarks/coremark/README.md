# CoreMark Benchmark for utoss-risc-v

Bare-metal [EEMBC CoreMark](https://github.com/eembc/coremark) harness for gathering consistent
**CPI (Cycles Per Instruction)**, **IPC**, stall/flush breakdowns, and **CoreMark/MHz** metrics on
`utoss-risc-v` in Verilator simulation.

Only the UTOSS port and simulation glue live in this directory; upstream EEMBC CoreMark sources are
fetched automatically into `benchmarks/coremark/upstream/` (gitignored, pinned to a specific commit in
`Makefile`).

## Layout

- `port/` — Bare-metal RV32 glue (`core_portme.h`, `core_portme.c`, `crt0.S`, `link.ld`).
- `sim/coremark_tb.sv` — Verilator testbench wrapping `utoss_riscv` with 256 KB synchronous RAM,
  MMIO console/counters, and exact cycle/instruction-retirement tracking.
- `Makefile` — Fetches pinned upstream CoreMark on demand, compiles the RV32 binary, builds the
  Verilator sim, and runs the benchmark per ISA config.

## Quick Start

From the repository root:

```bash
# Run on base RV32I (default, 1 iteration; auto-fetches upstream CoreMark)
make -C benchmarks/coremark run

# Run on RV32IB (enables implemented B sub-extensions: Zbb + Zbkb + Zbkx)
make -C benchmarks/coremark run UTOSS_RISCV_CONFIG=RV32IB

# Run on RV32IM or RV32IMB
make -C benchmarks/coremark run UTOSS_RISCV_CONFIG=RV32IM
make -C benchmarks/coremark run UTOSS_RISCV_CONFIG=RV32IMB

# Compare RV32I vs RV32IB back-to-back
make -C benchmarks/coremark compare
```

You can also run from the root `Makefile`:

```bash
make coremark UTOSS_RISCV_CONFIG=RV32IB
```

## Configuration Options

| Variable | Default | Description |
| :--- | :--- | :--- |
| `UTOSS_RISCV_CONFIG` | `RV32I` | Core ISA config (`RV32I`, `RV32IB`, `RV32IZbb_Zbkb`, `RV32IM`, `RV32IMB`, `RV32IZicsr`, etc.) |
| `MARCH` | derived | Override GCC `-march` string directly (defaults to implemented extensions, e.g., `rv32i_zbb_zbkb_zbkx` for `RV32IB`) |
| `COREMARK_DIR` | `upstream` | Path to upstream CoreMark checkout (auto-fetched at pinned `COREMARK_REF` if missing) |
| `ITERATIONS` | `1` | Number of CoreMark iterations (`1` runs in ~1s in Verilator; increase for longer runs) |
| `OPT_FLAGS` | `-O2` | Compiler optimization flags (keep fixed when comparing microarchitecture changes) |
| `MAX_CYCLES` | `50000000` | Simulation cycle timeout |
| `TRACE` / `VCD_PATH` | `0` / empty | Set `TRACE=1 VCD_PATH=out/wave.vcd` to dump waveforms |

## How CPI is Measured

- `start_time()` and `stop_time()` in `port/core_portme.c` bracket only CoreMark's `iterate()` loop
  via MMIO (`0x1000_0004`), excluding startup (`crt0.S`), initialization, and `ee_printf()`
  overhead.
- `sim/coremark_tb.sv` counts every clock cycle and every **retired instruction** (a valid,
  non-flushed, non-bubble instruction reaching writeback: `uut.mem_to_wb_reg.pc_plus_4 != 32'h0`),
  plus stall and flush cycles.
- Note on `RV32IB`: `src/stages/execute_stage.sv` currently wires up **`Zbb`, `Zbkb`, and `Zbkx`**
  under `UTOSS_RISCV__ENABLE_B_EXT` (not `Zba` or `Zbs`), so `UTOSS_RISCV_CONFIG=RV32IB` compiles
  with `-march=rv32i_zbb_zbkb_zbkx`.
