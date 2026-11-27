# ==============================================================================
# CoreMark benchmark build & Verilator runner for utoss-risc-v
# ==============================================================================

REPO_ROOT    ?= $(abspath ..)
SRC_DIR      := $(REPO_ROOT)/src
PORT_DIR     := port
SIM_DIR      := sim
BUILD_ROOT   := build
OUT_ROOT     := out

# Upstream EEMBC CoreMark source (fetched automatically if not present;
# override COREMARK_DIR to point at an existing local checkout).
COREMARK_REPO ?= https://github.com/eembc/coremark.git
COREMARK_REF  ?= 1f483d5b8316753a742cbf5590caf5bd0a4e4777
COREMARK_DIR  ?= upstream

# Core ISA configuration matching root Makefile conventions, plus RV32IB alias.
# Examples:
#   make run                                      # RV32I
#   make run UTOSS_RISCV_CONFIG=RV32IB            # RV32I + implemented B ext (Zbb+Zbkb+Zbkx)
#   make run UTOSS_RISCV_CONFIG=RV32IZbb_Zbkb     # Explicit B sub-extensions
#   make run UTOSS_RISCV_CONFIG=RV32IM            # RV32I + M ext
#   make run UTOSS_RISCV_CONFIG=RV32IMB           # RV32I + M + implemented B ext
UTOSS_RISCV_CONFIG ?= RV32I

# Benchmark parameters
ITERATIONS   ?= 1
OPT_FLAGS    ?= -O2
MAX_CYCLES   ?= 50000000
TRACE        ?= 0
VCD_PATH     ?=

# Toolchain
RISCV_PREFIX ?= riscv32-unknown-elf-
CC           := $(RISCV_PREFIX)gcc
OBJCOPY      := $(RISCV_PREFIX)objcopy
OBJDUMP      := $(RISCV_PREFIX)objdump
SIZE         := $(RISCV_PREFIX)size
VERILATOR    := verilator

# Map UTOSS_RISCV_CONFIG -> Verilator RTL defines
# Note: in src/stages/execute_stage.sv, UTOSS_RISCV__ENABLE_B_EXT enables zbb, zbkb, zbkx.
HAS_B_EXT     := $(or $(findstring Zbb,$(UTOSS_RISCV_CONFIG)),$(findstring Zbkb,$(UTOSS_RISCV_CONFIG)),$(findstring Zbkx,$(UTOSS_RISCV_CONFIG)),$(findstring B,$(UTOSS_RISCV_CONFIG)))
HAS_M_EXT     := $(findstring M,$(UTOSS_RISCV_CONFIG))
HAS_ZICSR_EXT := $(findstring Zicsr,$(UTOSS_RISCV_CONFIG))

VERILATOR_DEFINES := \
	$(if $(HAS_B_EXT),-DUTOSS_RISCV__ENABLE_B_EXT) \
	$(if $(HAS_M_EXT),-DUTOSS_RISCV__ENABLE_M_EXT) \
	$(if $(HAS_ZICSR_EXT),-DUTOSS_RISCV__ENABLE_ZICSR_EXT)

# Map UTOSS_RISCV_CONFIG -> GCC -march (overrideable via MARCH=...)
DEFAULT_MARCH := rv32i$(if $(HAS_M_EXT),m)
ifneq ($(HAS_B_EXT),)
DEFAULT_MARCH := $(DEFAULT_MARCH)_zbb_zbkb_zbkx
endif
ifneq ($(HAS_ZICSR_EXT),)
DEFAULT_MARCH := $(DEFAULT_MARCH)_zicsr
endif

MARCH ?= $(DEFAULT_MARCH)
MABI  ?= ilp32

# Per-config build directories so switching configs never mixes stale binaries
CFG_TAG   := $(UTOSS_RISCV_CONFIG)
BUILD_DIR := $(BUILD_ROOT)/$(CFG_TAG)
OUT_DIR   := $(OUT_ROOT)/$(CFG_TAG)

COREMARK_ELF := $(OUT_DIR)/coremark.elf
COREMARK_MEM := $(OUT_DIR)/coremark.mem
COREMARK_DIS := $(OUT_DIR)/coremark.dis
SIM_BIN      := $(OUT_DIR)/coremark_sim

UPSTREAM_SRCS := \
	$(COREMARK_DIR)/core_list_join.c \
	$(COREMARK_DIR)/core_main.c \
	$(COREMARK_DIR)/core_matrix.c \
	$(COREMARK_DIR)/core_state.c \
	$(COREMARK_DIR)/core_util.c

PORT_SRCS   := $(PORT_DIR)/core_portme.c
STARTUP_SRC := $(PORT_DIR)/crt0.S
LINKER_LD   := $(PORT_DIR)/link.ld

CFLAGS := \
	-march=$(MARCH) \
	-mabi=$(MABI) \
	$(OPT_FLAGS) \
	-ffreestanding \
	-fno-builtin \
	-nostdlib \
	-nostartfiles \
	-Wall \
	-Wextra \
	-Wno-unused-parameter \
	-I$(COREMARK_DIR) \
	-I$(PORT_DIR) \
	-DITERATIONS=$(ITERATIONS) \
	-DPERFORMANCE_RUN=1 \
	-DFLAGS_STR="\"-march=$(MARCH) $(OPT_FLAGS)\""

LDFLAGS := \
	-march=$(MARCH) \
	-mabi=$(MABI) \
	-nostdlib \
	-nostartfiles \
	-T $(LINKER_LD) \
	-Wl,--gc-sections \
	-Wl,--no-warn-rwx-segments

RTL_SRCS := $(sort $(shell find $(SRC_DIR) -name "*.sv" -o -name "*.v"))
TB_SRC   := $(SIM_DIR)/coremark_tb.sv

VERILATOR_FLAGS := \
	-Wall \
	--binary \
	--timing \
	-sv \
	-cc \
	-O3 \
	-I$(REPO_ROOT) \
	-CFLAGS "-Wno-unknown-warning-option" \
	$(if $(filter 1,$(TRACE)),--trace) \
	$(VERILATOR_DEFINES)

SIM_PLUSARGS := \
	+MEM=$(COREMARK_MEM) \
	+MAX_CYCLES=$(MAX_CYCLES) \
	+ITERATIONS=$(ITERATIONS) \
	+ISA=$(UTOSS_RISCV_CONFIG)/$(MARCH) \
	$(if $(VCD_PATH),+VCD_PATH=$(VCD_PATH))

.PHONY: all fetch build_sw build_sim run disasm compare clean distclean

all: build_sw build_sim

fetch: $(COREMARK_DIR)/coremark.h

$(COREMARK_DIR)/coremark.h:
	@echo "Fetching EEMBC CoreMark ($(COREMARK_REF)) into $(COREMARK_DIR)..."
	git init $(COREMARK_DIR)
	git -C $(COREMARK_DIR) remote add origin $(COREMARK_REPO)
	git -C $(COREMARK_DIR) fetch --depth 1 origin $(COREMARK_REF)
	git -C $(COREMARK_DIR) checkout --detach FETCH_HEAD

$(UPSTREAM_SRCS): $(COREMARK_DIR)/coremark.h

build_sw: $(COREMARK_MEM)

$(COREMARK_ELF): $(UPSTREAM_SRCS) $(COREMARK_DIR)/coremark.h $(PORT_SRCS) $(STARTUP_SRC) $(LINKER_LD) $(PORT_DIR)/core_portme.h
	@mkdir -p $(OUT_DIR)
	$(CC) $(CFLAGS) $(STARTUP_SRC) $(UPSTREAM_SRCS) $(PORT_SRCS) $(LDFLAGS) -lgcc -o $@
	$(SIZE) $@

$(COREMARK_MEM): $(COREMARK_ELF)
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

disasm: $(COREMARK_ELF)
	$(OBJDUMP) -d -M numeric,no-aliases $< > $(COREMARK_DIS)
	@echo "Disassembly written to $(COREMARK_DIS)"

build_sim: $(SIM_BIN)

$(SIM_BIN): $(RTL_SRCS) $(TB_SRC)
	@mkdir -p $(BUILD_DIR)/verilator $(OUT_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module coremark_tb \
		--Mdir $(BUILD_DIR)/verilator \
		-o coremark_sim \
		$(RTL_SRCS) $(TB_SRC)
	cp $(BUILD_DIR)/verilator/coremark_sim $@

run: $(COREMARK_MEM) $(SIM_BIN)
	./$(SIM_BIN) $(SIM_PLUSARGS)

compare:
	@echo "=== Running CoreMark: RV32I ==="
	$(MAKE) run UTOSS_RISCV_CONFIG=RV32I ITERATIONS=$(ITERATIONS) OPT_FLAGS="$(OPT_FLAGS)"
	@echo "=== Running CoreMark: RV32IB (Zbb+Zbkb+Zbkx) ==="
	$(MAKE) run UTOSS_RISCV_CONFIG=RV32IB ITERATIONS=$(ITERATIONS) OPT_FLAGS="$(OPT_FLAGS)"

clean:
	rm -rf $(BUILD_ROOT) $(OUT_ROOT)

distclean: clean
	rm -rf $(COREMARK_DIR)
