QUARTUS_PROJECT_NAME := utoss-risc-v

SCRIPTS_DIR := scripts
METRICS_DIR := metrics

QUARTUS_SHELL := quartus_sh
QUARTUS_CDB   := quartus_cdb
QUARTUS_ASM   := quartus_asm

UTOSS_RISCV_CONFIG ?= RV32I

synthesize:
	QUARTUS_PROJECT_NAME=$(QUARTUS_PROJECT_NAME) UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG) \
		$(QUARTUS_SHELL) -t $(SCRIPTS_DIR)/synthesize.tcl

refresh_ram:
	$(QUARTUS_CDB) $(QUARTUS_PROJECT_NAME) --update_mif
	$(QUARTUS_ASM) $(QUARTUS_PROJECT_NAME)

$(METRICS_DIR)/fitter_utilization.csv: $(SCRIPTS_DIR)/panel_to_csv.tcl
	$(QUARTUS_SHELL) -t $< "Fitter||Resource Section||Fitter Resource Utilization by Entity" $@

%.pretty.txt: %.csv
	column -s, -t $< > $@

list_panels:
	$(QUARTUS_SHELL) -t $(SCRIPTS_DIR)/list_panels.tcl

metrics: $(METRICS_DIR)/fitter_utilization.csv
pretty-metrics: $(METRICS_DIR)/fitter_utilization.pretty.txt

# placement figures are checked in (one directory per config) and verified by `make test_images`
IMAGES_DIR    ?= images/$(UTOSS_RISCV_CONFIG)
PLACEMENT_TSV := output_files/placement.tsv
PYTHON        := python3
OPTIPNG       := optipng -quiet -o2 -strip all

# draw the placement figures from the last `make synthesize`: dump the placement with the Chip
# Planner Tcl package, then plot it with matplotlib
images:
	$(QUARTUS_CDB) -t $(SCRIPTS_DIR)/dump_placement.tcl $(QUARTUS_PROJECT_NAME) $(PLACEMENT_TSV)
	$(PYTHON) $(SCRIPTS_DIR)/plot_placement.py --placement $(PLACEMENT_TSV) \
		--fit-summary output_files/$(QUARTUS_PROJECT_NAME).fit.summary \
		--out-dir $(IMAGES_DIR) --config $(UTOSS_RISCV_CONFIG)
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

.PHONY: synthesize refresh_ram list_panels images test_images
