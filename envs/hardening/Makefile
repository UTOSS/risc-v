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

# layout figures are checked in (one directory per config) and verified by `make test_harden_images`
IMAGES_DIR ?= images/$(UTOSS_RISCV_CONFIG)
LAYOUT_DIR := $(OUT_DIR)/layout
# the dump runs the OpenROAD GUI headless (heatmaps are only computed by the GUI); -no_settings
# keeps a user's saved GUI preferences out of it
DUMP_LAYOUT := QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=$(abspath $(OUT_DIR)) \
	$(OPENROAD) -gui -no_splash -no_settings $(SCRIPTS_DIR)/dump_layout.tcl
OPTIPNG := optipng -quiet -o2 -strip all

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

# synthesis + place & route + post-PnR metrics (without re-rendering checked-in layout PNGs)
harden_pnr: harden_pre_pnr
	@mkdir -p $(PNR_DIR) $(METRICS_DIR)
	set -o pipefail; $(OPENROAD) -no_init -exit $(SCRIPTS_DIR)/harden.tcl 2>&1 | tee $(PNR_DIR)/pnr.log
	$(PYTHON) $(SCRIPTS_DIR)/parse_pnr_metrics.py \
		--pnr-dir $(PNR_DIR) \
		--csv $(METRICS_DIR)/pnr_utilization.csv \
		--pretty $(METRICS_DIR)/pnr_utilization.pretty.txt \
		--gates $(METRICS_DIR)/pnr_gate_breakdown.txt \
		--timing $(METRICS_DIR)/pnr_timing.txt

# full hardening: synthesis, place & route, metrics, and layout images
harden: harden_pnr harden_images

# draw the layout figures from the stage snapshots of the last `make harden` run: dump each
# snapshot's geometry with OpenROAD, then plot it with matplotlib
harden_images:
	DUMP_ODB=$(PNR_DIR)/1_floorplan.odb DUMP_DIR=$(LAYOUT_DIR)/1_floorplan $(DUMP_LAYOUT)
	DUMP_ODB=$(PNR_DIR)/2_place.odb     DUMP_DIR=$(LAYOUT_DIR)/2_place     $(DUMP_LAYOUT)
	DUMP_ODB=$(PNR_DIR)/3_cts.odb       DUMP_DIR=$(LAYOUT_DIR)/3_cts       $(DUMP_LAYOUT)
	DUMP_ODB=$(PNR_DIR)/top.odb         DUMP_DIR=$(LAYOUT_DIR)/top DUMP_HEATMAPS=Routing $(DUMP_LAYOUT)
	$(PYTHON) $(SCRIPTS_DIR)/plot_layout.py --dump-dir $(LAYOUT_DIR) --out-dir $(IMAGES_DIR) \
		--config $(UTOSS_RISCV_CONFIG)
	$(OPTIPNG) $(IMAGES_DIR)/*.png

# check that the checked-in images match what `make harden` just produced (run after it)
test_harden_images:
	@untracked=$$(git ls-files --others --exclude-standard -- $(IMAGES_DIR)); \
	if [ -n "$$untracked" ]; then \
		echo "ERROR: layout images are not checked in:"; echo "$$untracked"; \
		echo "Run 'make harden UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)' and commit $(IMAGES_DIR)/."; \
		exit 1; \
	fi
	@if ! git diff --quiet -- $(IMAGES_DIR); then \
		echo "ERROR: layout images differ from the checked-in ones:"; \
		git diff --stat -- $(IMAGES_DIR); \
		echo "Run 'make harden UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)' and commit $(IMAGES_DIR)/."; \
		exit 1; \
	fi
	@echo "Layout images in $(IMAGES_DIR) are up to date."

clean:
	rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR) && touch $(OUT_DIR)/.gitkeep
	@if [ -d "$(METRICS_DIR)" ]; then \
		find $(METRICS_DIR) -mindepth 1 ! -name '.gitkeep' -delete; \
	fi

.PHONY: all harden_pre_pnr harden_pnr harden harden_images test_harden_images clean
