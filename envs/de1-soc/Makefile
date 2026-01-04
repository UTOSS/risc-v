VERILATOR := verilator

BASE_INCLUDE_DIR := ../../
OUT_DIR          := out
BUILD_DIR        := build

CORE_SRC   := $(shell find $(BASE_INCLUDE_DIR)src -name "*.sv" -o -name "*.v")
LOCAL_SRCS := $(wildcard *.sv)

VERILATOR_FLAGS := -Wall --binary --trace --timing -sv -cc \
	-I$(BASE_INCLUDE_DIR) \
	-O3 -Wno-fatal

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
	cd quartus && quartus_sh --flow compile utoss-risc-v

clean:
	rm -rf $(OUT_DIR) $(BUILD_DIR)

.PHONY: all run_tb poc clean
