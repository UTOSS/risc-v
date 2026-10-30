BASE_DIR 		:= ../..
SCRIPTS_DIR := scripts
METRICS_DIR := metrics
OUT_DIR     := out

PDK_LIB ?= /opt/pdks/nangate45/NangateOpenCellLibrary_typical.lib

UTOSS_RISCV_CONFIG ?= RV32I
MEM_SIZE    			 ?= 128
BOOT_ADDR   			 ?= 0

YOSYS  := yosys
PYTHON := python3

export UTOSS_RISCV_CONFIG MEM_SIZE BOOT_ADDR PDK_LIB OUT_DIR METRICS_DIR BASE_DIR

all: harden

harden:
	@mkdir -p $(OUT_DIR) $(METRICS_DIR)
	$(YOSYS) -c $(SCRIPTS_DIR)/harden.tcl
	$(PYTHON) $(SCRIPTS_DIR)/parse_metrics.py \
		--json $(OUT_DIR)/stats.json \
		--csv $(METRICS_DIR)/synthesis_utilization.csv \
		--pretty $(METRICS_DIR)/synthesis_utilization.pretty.txt \
		--gates $(METRICS_DIR)/gate_breakdown.txt

clean:
	rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR) && touch $(OUT_DIR)/.gitkeep
	@if [ -d "$(METRICS_DIR)" ]; then \
		find $(METRICS_DIR) -mindepth 1 ! -name '.gitkeep' -delete; \
	fi

.PHONY: all harden clean
