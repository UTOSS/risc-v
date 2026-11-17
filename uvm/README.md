# Native SystemVerilog UVM verification with Verilator

This directory contains separate SystemVerilog UVM benches for the two
existing `PyUVM/` flows. `PyUVM/` remains unchanged.

- `alu/alu_uvm.sv` contains the standalone ALU agent, directed sequence,
  independent reference model, scoreboard, and coverage counters.
- `core/ecall_uvm.sv` contains the full-core program driver, register-write,
  memory-store, and trap monitors, event-stream scoreboard, and four ECALL
  scenarios (basic trap, relocated handler, wrong-path flush, non-ECALL CSR).

Each bench has its own top module and build directory. The ALU build compiles
only the ALU RTL; the core build compiles the simulation core with Zicsr.

## Requirements and UVM installation

- Verilator with SystemVerilog UVM support
- make and a C++20-capable compiler
- Accellera UVM 2020.3.1 source tree, installed by the devcontainer at
  `/opt/uvm/1800.2-2020.3.1/src` and exposed as `UVM_HOME`

Run these targets inside the devcontainer. For another environment, set
`UVM_HOME` to the installed UVM `src` directory.

## Build and run

```sh
make -C uvm run-alu       # Standalone ALU bench
make -C uvm run-ecall     # Four full-core ECALL tests; requires Zicsr
make -C uvm run           # Both benches
```

The default core configuration is `UTOSS_RISCV_CONFIG=RV32IZicsr`. Build
products are kept separately in `uvm/build/alu/` and `uvm/build/ecall/`. Each
bench compiles its own UVM library model on its first build.
