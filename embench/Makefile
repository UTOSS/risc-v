# ==============================================================================
# Embench-IoT benchmark suite build & Verilator runner for utoss-risc-v
# ==============================================================================

REPO_ROOT    ?= $(abspath ..)
SRC_DIR      := $(REPO_ROOT)/src
PORT_DIR     := port
SIM_DIR      := sim
BUILD_ROOT   := build
OUT_ROOT     := out

# Upstream Embench-IoT source (fetched automatically if not present;
# override EMBENCH_DIR to point at an existing local checkout).
EMBENCH_REPO ?= https://github.com/embench/embench-iot.git
EMBENCH_REF  ?= 09c2ed8c3b7008c95d08b038de4a3f6dc103ed70
EMBENCH_DIR  ?= upstream

# Core ISA configuration matching root Makefile conventions, plus RV32IB alias.
# Examples:
#   make run                                            # All 19 benchmarks on RV32I
#   make run UTOSS_RISCV_CONFIG=RV32IB                  # All 19 benchmarks on RV32I+Zbb/Zbkb/Zbkx
#   make run BENCHMARKS="crc32 picojpeg nettle-aes"     # Selected subset
UTOSS_RISCV_CONFIG ?= RV32I

ALL_BENCHMARKS := \
	aha-mont64 \
	crc32 \
	depthconv \
	edn \
	huffbench \
	matmult-int \
	md5sum \
	nettle-aes \
	nettle-sha256 \
	nsichneu \
	picojpeg \
	qrduino \
	sglib-combined \
	slre \
	statemate \
	tarfind \
	ud \
	wikisort \
	xgboost

BENCHMARKS   ?= $(ALL_BENCHMARKS)
GSF          ?= 1
WARMUP_HEAT  ?= 0
OPT_FLAGS    ?= -O2
MAX_CYCLES   ?= 200000000
JOBS         ?= $(shell nproc)
TRACE        ?= 0

# Toolchain
RISCV_PREFIX ?= riscv32-unknown-elf-
CC           := $(RISCV_PREFIX)gcc
OBJCOPY      := $(RISCV_PREFIX)objcopy
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

# Per-config directories so switching configs never mixes stale artifacts
CFG_TAG   := $(UTOSS_RISCV_CONFIG)
BUILD_DIR := $(BUILD_ROOT)/$(CFG_TAG)
OUT_DIR   := $(OUT_ROOT)/$(CFG_TAG)

SIM_BIN   := $(OUT_DIR)/embench_sim
ELF_DIR   := $(OUT_DIR)/elf
MEM_DIR   := $(OUT_DIR)/mem
JSON_OUT  := $(OUT_DIR)/results.json

SUPPORT_SRCS := \
	$(EMBENCH_DIR)/support/main.c \
	$(EMBENCH_DIR)/support/beebsc.c \
	$(PORT_DIR)/boardsupport.c

STARTUP_SRC := $(PORT_DIR)/crt0.S
LINKER_LD   := $(PORT_DIR)/link.ld

CFLAGS := \
	-std=gnu17 \
	-march=$(MARCH) \
	-mabi=$(MABI) \
	$(OPT_FLAGS) \
	-ffunction-sections \
	-fdata-sections \
	-I$(EMBENCH_DIR)/support \
	-I$(PORT_DIR) \
	-DHAVE_BOARDSUPPORT_H \
	-DWARMUP_HEAT=$(WARMUP_HEAT) \
	-DGLOBAL_SCALE_FACTOR=$(GSF)

LDFLAGS := \
	-march=$(MARCH) \
	-mabi=$(MABI) \
	--specs=nano.specs \
	--specs=nosys.specs \
	-nostartfiles \
	-T $(LINKER_LD) \
	-Wl,--gc-sections \
	-Wl,--no-warn-rwx-segments

LIBS := -lm -lc -lgcc

RTL_SRCS := $(sort $(shell find $(SRC_DIR) -name "*.sv" -o -name "*.v"))
TB_SRC   := $(SIM_DIR)/embench_tb.sv

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

BENCH_ELFS := $(patsubst %,$(ELF_DIR)/%.elf,$(BENCHMARKS))
BENCH_MEMS := $(patsubst %,$(MEM_DIR)/%.mem,$(BENCHMARKS))

.PRECIOUS: $(ELF_DIR)/%.elf

.PHONY: all fetch list build_sw build_sim run compare clean distclean

all: build_sw build_sim

list:
	@echo "$(ALL_BENCHMARKS)"

fetch: $(EMBENCH_DIR)/support/main.c

$(EMBENCH_DIR)/support/main.c:
	@echo "Fetching Embench-IoT ($(EMBENCH_REF)) into $(EMBENCH_DIR)..."
	git init $(EMBENCH_DIR)
	git -C $(EMBENCH_DIR) remote add origin $(EMBENCH_REPO)
	git -C $(EMBENCH_DIR) fetch --depth 1 origin $(EMBENCH_REF)
	git -C $(EMBENCH_DIR) checkout --detach FETCH_HEAD

$(ELF_DIR)/%.elf: $(EMBENCH_DIR)/support/main.c $(PORT_DIR)/boardsupport.c $(PORT_DIR)/boardsupport.h $(STARTUP_SRC) $(LINKER_LD)
	@mkdir -p $(ELF_DIR)
	$(CC) $(CFLAGS) -I$(EMBENCH_DIR)/src/$* \
		$(STARTUP_SRC) $(SUPPORT_SRCS) $(wildcard $(EMBENCH_DIR)/src/$*/*.c) \
		$(LDFLAGS) $(LIBS) -o $@

$(MEM_DIR)/%.mem: $(ELF_DIR)/%.elf
	@mkdir -p $(MEM_DIR)
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

build_sw: fetch $(BENCH_ELFS) $(BENCH_MEMS)

build_sim: $(SIM_BIN)

$(SIM_BIN): $(RTL_SRCS) $(TB_SRC)
	@mkdir -p $(BUILD_DIR)/verilator $(OUT_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module embench_tb \
		--Mdir $(BUILD_DIR)/verilator \
		-o embench_sim \
		$(RTL_SRCS) $(TB_SRC)
	cp $(BUILD_DIR)/verilator/embench_sim $@

run: build_sw build_sim
	python3 run_embench.py \
		--sim $(SIM_BIN) \
		--out-dir $(OUT_DIR) \
		--isa $(UTOSS_RISCV_CONFIG)/$(MARCH) \
		--max-cycles $(MAX_CYCLES) \
		--jobs $(JOBS) \
		--size-tool $(SIZE) \
		--json-out $(JSON_OUT) \
		$(BENCHMARKS)

compare:
	@echo "=== Running Embench-IoT: RV32I ==="
	$(MAKE) run UTOSS_RISCV_CONFIG=RV32I BENCHMARKS="$(BENCHMARKS)" OPT_FLAGS="$(OPT_FLAGS)"
	@echo "=== Running Embench-IoT: RV32IB (Zbb+Zbkb+Zbkx) ==="
	$(MAKE) run UTOSS_RISCV_CONFIG=RV32IB BENCHMARKS="$(BENCHMARKS)" OPT_FLAGS="$(OPT_FLAGS)"

clean:
	rm -rf $(BUILD_ROOT) $(OUT_ROOT)

distclean: clean
	rm -rf $(EMBENCH_DIR)
