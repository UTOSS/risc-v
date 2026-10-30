VERILATOR := verilator

BASE_INCLUDE_DIR := ../../
OUT_DIR          := out
BUILD_DIR        := build

CORE_SRC   := $(shell find $(BASE_INCLUDE_DIR)src -name "*.sv" -o -name "*.v")
LOCAL_SRCS := $(wildcard *.sv)

UTOSS_RISCV_CONFIG ?= $(if $(RISCOF_ISA_STRING),$(RISCOF_ISA_STRING),RV32I)

UTOSS_RISCV_VERILATOR_DEFINES := \
	$(if $(findstring Zbb,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV_ENABLE_B_EXT) \
	$(if $(findstring Zicsr,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV__ZICSR_ENABLED) \
	$(if $(findstring M,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV__M_ENABLED -DUTOSS_RISCV__MUL_ENABLED -DUTOSS_RISCV__DIV_ENABLED -DUTOSS_RISCV__ANY_M)

VERILATOR_FLAGS := -Wall --binary --trace --timing -sv -cc \
	-I$(BASE_INCLUDE_DIR) \
	-O3 -Wno-fatal \
	$(UTOSS_RISCV_VERILATOR_DEFINES)

all: run_tb

# ===========================
# Sub-project
# ===========================
poc:
	$(MAKE) -C poc

$(OUT_DIR)/top_tb_sim: poc $(LOCAL_SRCS) $(CORE_SRC)
	@mkdir -p $(OUT_DIR)
	@mkdir -p $(BUILD_DIR)/top_tb
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module top_tb \
		--Mdir $(BUILD_DIR)/top_tb \
		-o top_tb_sim \
		$(LOCAL_SRCS) $(CORE_SRC)
	cp $(BUILD_DIR)/top_tb/top_tb_sim $@

run_tb: $(OUT_DIR)/top_tb_sim
	./$<

synthesize:
	$(MAKE) -C quartus synthesize UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)

clean:
	rm -rf $(OUT_DIR) $(BUILD_DIR)

.PHONY: all run_tb poc synthesize clean
