# Embench-IoT Benchmark Suite for utoss-risc-v

Bare-metal [Embench-IoT 2.0](https://github.com/embench/embench-iot) harness for measuring
per-workload and geometric-mean **CPI (Cycles Per Instruction)**, **IPC**, and stall/flush
breakdowns across all **19 embedded C benchmarks** on `utoss-risc-v` in Verilator simulation.

Only the UTOSS port, simulation harness, and runner live in git; upstream Embench-IoT sources are
fetched automatically into `embench/upstream/` (gitignored, pinned to a specific commit in
`Makefile`).

## Quick Start

From the repository root:

```bash
# Run all 19 benchmarks on base RV32I (auto-fetches upstream Embench-IoT)
make -C embench run

# Run all 19 benchmarks on RV32IB (implemented B sub-extensions: Zbb + Zbkb + Zbkx)
make -C embench run UTOSS_RISCV_CONFIG=RV32IB

# Run a specific subset of benchmarks
make -C embench run UTOSS_RISCV_CONFIG=RV32IB BENCHMARKS="crc32 picojpeg nettle-aes nettle-sha256"

# Compare RV32I vs RV32IB back-to-back
make -C embench compare

# Or invoke from the root Makefile
make embench UTOSS_RISCV_CONFIG=RV32IB
```

## Configuration Options

| Variable | Default | Description |
| :--- | :--- | :--- |
| `UTOSS_RISCV_CONFIG` | `RV32I` | Core ISA config (`RV32I`, `RV32IB`, `RV32IZbb_Zbkb`, `RV32IM`, `RV32IMB`, `RV32IZicsr`, etc.) |
| `MARCH` | derived | Override GCC `-march` string directly (defaults to `rv32i_zbb_zbkb_zbkx` for `RV32IB`) |
| `BENCHMARKS` | all 19 | Space-separated subset of benchmarks to build and run |
| `EMBENCH_DIR` | `upstream` | Path to upstream Embench-IoT checkout (auto-fetched at pinned `EMBENCH_REF` if missing) |
| `OPT_FLAGS` | `-O2` | Compiler optimization flags |
| `GSF` | `1` | Embench `GLOBAL_SCALE_FACTOR` |
| `WARMUP_HEAT` | `0` | Cache warmup iterations (0 since core has no cache) |
| `MAX_CYCLES` | `200000000` | Per-benchmark simulation cycle timeout |
| `JOBS` | `$(nproc)` | Parallel Verilator simulation workers |

## How CPI is Measured

- `start_trigger()` and `stop_trigger()` in `port/boardsupport.c` bracket only each benchmark's
  `benchmark()` call via MMIO (`0x1000_0004`), excluding startup, data initialization, and
  verification.
- `sim/embench_tb.sv` counts timed cycles, **retired instructions** (`uut.mem_to_wb_reg.pc_plus_4 !=
  32'h0`), stalls, and flushes, and checks `verify_benchmark()` via `main()`'s exit code (`0` =
  PASS).
- `run_embench.py` runs all selected benchmarks in parallel, prints a per-benchmark + aggregate +
  geometric-mean CPI table, and saves machine-readable metrics to `out/<config>/results.json`.
