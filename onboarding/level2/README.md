# Onboarding Level 2: RISC-V Assembly Execution & Demonstration

Welcome to **Level 2** of the UTOSS RISC-V onboarding!

The goal of this level is to write your own RISC-V assembly instructions and see them execute on the
UTOSS RISC-V processor core in the simulation environment (`envs/simulation`), observing the
pipeline stages and final register values.

---

## Directory Overview

- [`main.s`](main.s): The boilerplate assembly file. You can add your own RISC-V instructions here.
- [`Makefile`](Makefile): Builds your assembly file into an ELF and `.mem` image, and runs it on the
  `envs/simulation` top simulator.
- [`link.ld`](link.ld): Linker script mapping code to `0x00000000` (the boot address of the
  simulation core).

---

## Quick Start

### 1. Build and Run the Assembly Simulation
From this directory, run:
```bash
make
```
or:
```bash
make run
```

This will:
1. Compile `main.s` using `riscv32-unknown-elf-gcc` into `main.elf`.
2. Convert `main.elf` to a Verilog hex memory file `main.mem` using `riscv32-unknown-elf-objcopy`.
3. Build the `envs/simulation` top-level simulator (`out/top_sim`) if not already built.
4. Pass `+MEM=.../main.mem` to the simulator and run it.

### 2. View Disassembly
To see the machine code and instruction addresses generated for your assembly:
```bash
make dump
```

### 3. View Raw ELF Hex Dump (xxd)
To inspect the raw byte representation of the compiled ELF binary:
```bash
make xxd
```

### 4. Custom Run Options
You can configure the simulation using command-line arguments:

- **Run with custom cycle limit**:
  ```bash
  make run CYCLES=50
  ```

- **Generate waveform VCD for GTKWave**:
  ```bash
  make run VCD=trace.vcd
  ```

- **Run a different assembly file**:
  ```bash
  make run SRC=my_program.s
  ```

- **Clean up artifacts**:
  ```bash
  make clean
  ```

---

## Writing Your Own Code

Open `main.s` in your editor and edit the code inside `_start`:
```assembly
.section .text
.globl _start

_start:
    # Your instructions here
    addi a0, zero, 42
    addi a1, zero, 8
    mul  a2, a0, a1

done:
    j done
```
Keep `done: j done` at the end so the core halts in a self-loop. The testbench detects this loop automatically and terminates simulation cleanly.
