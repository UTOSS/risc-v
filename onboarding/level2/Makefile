# ==============================================================================
# UTOSS RISC-V Onboarding - Level 2 Makefile Builds RISC-V assembly into a memory
# file and runs it on envs/simulation top simulation.
# ==============================================================================

RISCV_PREFIX  ?= riscv32-unknown-elf
RISCV_GCC     := $(RISCV_PREFIX)-gcc
RISCV_OBJCOPY := $(RISCV_PREFIX)-objcopy
RISCV_OBJDUMP := $(RISCV_PREFIX)-objdump
XXD           ?= xxd

SRC           ?= main.s
TARGET        ?= $(basename $(SRC))
LINK_SCRIPT   := link.ld

REPO_ROOT     := ../..
SIM_DIR       := $(REPO_ROOT)/envs/simulation
SIM_BIN       := $(REPO_ROOT)/out/top_sim

# Optional runtime overrides:
#   CYCLES=<N>   Maximum cycles to simulate (e.g. make run CYCLES=50)
#   VCD=<file>   Dump waveform to file (e.g. make run VCD=trace.vcd)
CYCLES_ARG    := $(if $(CYCLES),+CYCLES=$(CYCLES))
VCD_ARG       := $(if $(VCD),+VCD_PATH=$(VCD))

# GCC & OBJCOPY flags
ARCH          := rv32i
ABI           := ilp32
CFLAGS        := -march=$(ARCH) -mabi=$(ABI) -mno-relax \
                 -static -mcmodel=medany -fvisibility=hidden \
                 -nostdlib -nostartfiles -g

# Default target: build and run simulation
all: run

# Ensure simulation binary is built
$(SIM_BIN):
	@echo "Building envs/simulation top simulator..."
	$(MAKE) -C $(SIM_DIR)

# Compile assembly to ELF
$(TARGET).elf: $(SRC) $(LINK_SCRIPT)
	@echo "Compiling $(SRC) -> $@"
	$(RISCV_GCC) $(CFLAGS) -T $(LINK_SCRIPT) $< -o $@

# Convert ELF to Verilog hex memory file
$(TARGET).mem: $(TARGET).elf
	@echo "Generating memory image $@..."
	$(RISCV_OBJCOPY) -O verilog --verilog-data-width=4 $< $@

# Disassemble ELF
$(TARGET).dump: $(TARGET).elf
	@echo "Disassembling $< -> $@"
	$(RISCV_OBJDUMP) -d $< > $@

# Generate xxd hex dump of ELF
$(TARGET).hex: $(TARGET).elf
	@echo "Generating hex dump $< -> $@"
	$(XXD) $< > $@

# Build memory image and dumps
build: $(TARGET).mem $(TARGET).dump $(TARGET).hex
	@echo "Build complete for $(TARGET)."

# Disassemble and print to stdout
dump: $(TARGET).dump
	@cat $<

# Hex dump and print to stdout
xxd: $(TARGET).hex
	@cat $<

# Run the simulation
run: $(TARGET).mem $(SIM_BIN)
	@echo "[LEVEL2] Running $(TARGET).mem in envs/simulation top..."
	$(SIM_BIN) +MEM=$(abspath $(TARGET).mem) $(CYCLES_ARG) $(VCD_ARG)

clean:
	rm -f *.elf *.mem *.dump *.hex *.xxd *.vcd

help:
	@echo "UTOSS RISC-V Onboarding Level 2"
	@echo "Targets:"
	@echo "  make              - Build and run assembly in simulator"
	@echo "  make run          - Same as above"
	@echo "  make build        - Assemble to .elf, .mem, .dump, and .hex without running"
	@echo "  make dump         - Display disassembly of assembled code"
	@echo "  make xxd          - Display xxd hex dump of the ELF binary"
	@echo "  make clean        - Remove build artifacts"
	@echo ""
	@echo "Options:"
	@echo "  SRC=<file.s>      - Specify custom assembly file (default: main.s)"
	@echo "  CYCLES=<N>        - Override cycle limit (default: 100)"
	@echo "  VCD=<file.vcd>    - Dump VCD waveform"

.PHONY: all build dump xxd run clean help
