BASE_INCLUDE_DIR := ../../
OUT_DIR          := $(BASE_INCLUDE_DIR)out
BUILD_DIR        := $(BASE_INCLUDE_DIR)build/simulation

VERILATOR        := verilator

CORE_SRC         := $(shell find $(BASE_INCLUDE_DIR)src -name "*.sv" -o -name "*.v")
LOCAL_SRCS       := $(wildcard *.sv)

UTOSS_RISCV_CONFIG ?= $(if $(RISCOF_ISA_STRING),$(RISCOF_ISA_STRING),RV32I)
UTOSS_BOOT_ADDR    ?= 32\'h0000_0000

UTOSS_RISCV_VERILATOR_DEFINES := \
	$(if $(findstring Zbb,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV_ENABLE_B_EXT) \
	$(if $(findstring Zicsr,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV__ZICSR_ENABLED) \
	$(if $(findstring M,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV__M_ENABLED -DUTOSS_RISCV__MUL_ENABLED -DUTOSS_RISCV__DIV_ENABLED -DUTOSS_RISCV__ANY_M)

VERILATOR_FLAGS := -Wall --binary --trace --timing -sv -cc -O3 \
	-CFLAGS "-Wno-unknown-warning-option" \
	-I$(BASE_INCLUDE_DIR) \
	-Wno-fatal \
	-GBOOT_ADDR=$(UTOSS_BOOT_ADDR) \
	-DUTOSS_PIPELINE_LOGGER \
	$(UTOSS_RISCV_VERILATOR_DEFINES)

SIM_BIN := $(OUT_DIR)/top_sim

all: $(SIM_BIN)

$(SIM_BIN): $(LOCAL_SRCS) $(CORE_SRC)
	@mkdir -p $(OUT_DIR)
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module top_tb \
		--Mdir $(BUILD_DIR) \
		-o top_sim \
		$(LOCAL_SRCS) $(CORE_SRC)
	cp $(BUILD_DIR)/top_sim $@

run: $(SIM_BIN)
	$(SIM_BIN) $(if $(MEM),+MEM=$(MEM)) $(if $(CYCLES),+CYCLES=$(CYCLES)) $(if $(VCD),+VCD_PATH=$(VCD))

clean:
	rm -rf $(BUILD_DIR) $(SIM_BIN)

.PHONY: all run clean
