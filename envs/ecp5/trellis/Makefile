SHELL := /bin/bash

PROJECT_NAME := utoss-risc-v

SCRIPTS_DIR := scripts
METRICS_DIR := metrics
OUT_DIR     := out
BASE_DIR    := ../../..

# Target device: Lattice LFE5U-25F-7BG256I (ECP5-25K, CABGA256, speed grade 7, industrial)
ECP5_DEVICE  := 25k
ECP5_PACKAGE := CABGA256
ECP5_SPEED   := 7
ECP5_PART    := LFE5U-25F-7BG256I
LPF_FILE     := $(PROJECT_NAME).lpf
PNR_SEED     ?= 1

YOSYS   := yosys
NEXTPNR := nextpnr-ecp5
ECPPACK := ecppack
PYTHON  := python3
OPTIPNG := optipng -quiet -o2 -strip all

UTOSS_RISCV_CONFIG ?= RV32I

# placement figures are checked in (one directory per config) and verified by `make test_images`
IMAGES_DIR ?= images/$(UTOSS_RISCV_CONFIG)

export UTOSS_RISCV_CONFIG OUT_DIR BASE_DIR

all: synthesize pretty-metrics

synthesize:
	@mkdir -p $(OUT_DIR)
	$(YOSYS) -c $(SCRIPTS_DIR)/synthesize.tcl
	set -o pipefail; $(NEXTPNR) \
		--$(ECP5_DEVICE) \
		--package $(ECP5_PACKAGE) \
		--speed $(ECP5_SPEED) \
		--seed $(PNR_SEED) \
		--timing-allow-fail \
		--json $(OUT_DIR)/top.json \
		--lpf $(LPF_FILE) \
		--textcfg $(OUT_DIR)/$(PROJECT_NAME).config \
		--report $(OUT_DIR)/pnr_report.json \
		--write $(OUT_DIR)/top_placed.json \
		2>&1 | tee $(OUT_DIR)/nextpnr.log
	$(ECPPACK) --compress $(OUT_DIR)/$(PROJECT_NAME).config $(OUT_DIR)/$(PROJECT_NAME).bit

metrics:
	@mkdir -p $(METRICS_DIR)
	$(PYTHON) $(SCRIPTS_DIR)/parse_metrics.py \
		--synth-stats $(OUT_DIR)/synth_stats.json \
		--pnr-report $(OUT_DIR)/pnr_report.json \
		--placed-json $(OUT_DIR)/top_placed.json \
		--device $(ECP5_PART) \
		--csv $(METRICS_DIR)/pnr_utilization.csv \
		--pretty $(METRICS_DIR)/pnr_utilization.pretty.txt \
		--summary $(METRICS_DIR)/pnr_summary.txt \
		--timing $(METRICS_DIR)/timing_summary.txt

pretty-metrics: metrics

images:
	$(PYTHON) $(SCRIPTS_DIR)/plot_placement.py \
		--placed-json $(OUT_DIR)/top_placed.json \
		--pnr-report $(OUT_DIR)/pnr_report.json \
		--device $(ECP5_PART) \
		--out-dir $(IMAGES_DIR) \
		--config $(UTOSS_RISCV_CONFIG)
	$(OPTIPNG) $(IMAGES_DIR)/*.png

# check that the checked-in figures match what `make synthesize images` just produced
test_images:
	@untracked=$$(git ls-files --others --exclude-standard -- $(IMAGES_DIR)); \
	if [ -n "$$untracked" ]; then \
		echo "ERROR: placement figures are not checked in:"; echo "$$untracked"; \
		echo "Run 'make synthesize images UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)' and commit $(IMAGES_DIR)/."; \
		exit 1; \
	fi
	@if ! git diff --quiet -- $(IMAGES_DIR); then \
		echo "ERROR: placement figures differ from the checked-in ones:"; \
		git diff --stat -- $(IMAGES_DIR); \
		echo "Run 'make synthesize images UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)' and commit $(IMAGES_DIR)/."; \
		exit 1; \
	fi
	@echo "Placement figures in $(IMAGES_DIR) are up to date."

clean:
	rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR) && touch $(OUT_DIR)/.gitkeep
	@if [ -d "$(METRICS_DIR)" ]; then \
		find $(METRICS_DIR) -mindepth 1 ! -name '.gitkeep' -delete; \
	fi

.PHONY: all synthesize metrics pretty-metrics images test_images clean
