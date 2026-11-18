SHELL := /bin/bash

BASE_DIR 		:= ../..
SCRIPTS_DIR := scripts
METRICS_DIR := metrics
OUT_DIR     := out

PDK_DIR   ?= /opt/pdks/nangate45
PDK_LIB   ?= $(PDK_DIR)/NangateOpenCellLibrary_typical.lib
SDC_FILE  ?= constraints/top.sdc

# place & route knobs (see scripts/harden.tcl); Nangate45 platform settings are in platform/nangate45/
CLOCK_PERIOD       ?= 10
CORE_UTILIZATION   ?= 50
PLACE_DENSITY      ?= 0.65
PNR_DETAILED_ROUTE ?= 0
PNR_THREADS        ?= max

UTOSS_RISCV_CONFIG ?= RV32I
MEM_SIZE    			 ?= 128
BOOT_ADDR   			 ?= 0

YOSYS    := yosys
OPENROAD := openroad
PYTHON   := python3

PNR_DIR := $(OUT_DIR)/pnr

export UTOSS_RISCV_CONFIG MEM_SIZE BOOT_ADDR PDK_DIR PDK_LIB SDC_FILE OUT_DIR \
	METRICS_DIR BASE_DIR CLOCK_PERIOD CORE_UTILIZATION PLACE_DENSITY PNR_DETAILED_ROUTE PNR_THREADS

all: harden

# synthesis + pre-PnR utilization/gate breakdown; also writes $(OUT_DIR)/top_pnr.v for PnR
harden_pre_pnr:
	@mkdir -p $(OUT_DIR) $(METRICS_DIR)
	$(YOSYS) -c $(SCRIPTS_DIR)/harden_pre_pnr.tcl
	$(PYTHON) $(SCRIPTS_DIR)/parse_metrics.py \
		--json $(OUT_DIR)/stats.json \
		--csv $(METRICS_DIR)/synthesis_utilization.csv \
		--pretty $(METRICS_DIR)/synthesis_utilization.pretty.txt \
		--gates $(METRICS_DIR)/gate_breakdown.txt

# full hardening: synthesis, then place & route + post-PnR utilization/gate breakdown/timing
harden: harden_pre_pnr
	@mkdir -p $(PNR_DIR) $(METRICS_DIR)
	set -o pipefail; $(OPENROAD) -no_init -exit $(SCRIPTS_DIR)/harden.tcl 2>&1 | tee $(PNR_DIR)/pnr.log
	$(PYTHON) $(SCRIPTS_DIR)/parse_pnr_metrics.py \
		--pnr-dir $(PNR_DIR) \
		--csv $(METRICS_DIR)/pnr_utilization.csv \
		--pretty $(METRICS_DIR)/pnr_utilization.pretty.txt \
		--gates $(METRICS_DIR)/pnr_gate_breakdown.txt \
		--timing $(METRICS_DIR)/pnr_timing.txt

clean:
	rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR) && touch $(OUT_DIR)/.gitkeep
	@if [ -d "$(METRICS_DIR)" ]; then \
		find $(METRICS_DIR) -mindepth 1 ! -name '.gitkeep' -delete; \
	fi

.PHONY: all harden_pre_pnr harden clean
