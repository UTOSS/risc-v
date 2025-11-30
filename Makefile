# ===========================
# Directories and tools
# ===========================
SRC_DIR      := src
TB_DIR       := test
OUT_DIR      := out
BUILD_DIR    := build
VERILATOR    := verilator
TB_VCD_BASE_PATH := $(TB_DIR)/vcd

RISCOF_DIR           := riscof
RISCOF_DUT_SRC       := $(RISCOF_DIR)/dut.sv
RISCOF_DUT_BIN       := $(RISCOF_DIR)/dut_sim
RISCOF_CONFIG_TEMPLATE := $(RISCOF_DIR)/config.ini.m4
RISCOF_CONFIG        := $(RISCOF_DIR)/config.ini

VERILATOR_FLAGS := -Wall --binary --trace --timing -sv -cc \
	-O3 -Wno-fatal

# ===========================
# Sources
# ===========================
SRCS := $(shell find $(SRC_DIR) -name "*.sv" -o -name "*.v")
TB_SRCS := $(wildcard $(TB_DIR)/*_tb.sv)
TB_UTILS := $(TB_DIR)/utils.svh
TB_BINS := $(patsubst $(TB_DIR)/%_tb.sv, $(OUT_DIR)/%_tb_sim, $(TB_SRCS))

# ===========================
# Ensure directories exist
# ===========================
$(shell mkdir -p $(OUT_DIR))
$(shell mkdir -p $(TB_VCD_BASE_PATH))
$(shell mkdir -p $(BUILD_DIR)/top)

# ===========================
# Default
# ===========================
all: build_top
	@echo "Build finished! Try 'make run_top' or 'make run_tb'."

# ===========================
# Top module
# ===========================
build_top: $(OUT_DIR)/top_sim

run_top: $(OUT_DIR)/top_sim
	./$<

$(OUT_DIR)/top_sim: $(SRCS)
	@mkdir -p $(BUILD_DIR)/top
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module top \
		--Mdir $(BUILD_DIR)/top \
		-o top_sim \
		$(SRCS)
	cp $(BUILD_DIR)/top/top_sim $@

# ===========================
# Testbenches
# ===========================
build_tb: $(TB_BINS)

run_tb: build_tb
	@failed=0; \
	for tb in $(TB_BINS); do \
		echo "Running $$tb..."; \
		if ! ./$$tb +VCD_PATH=$(TB_VCD_BASE_PATH); then \
			echo "\033[31mFAILED: $$tb\033[0m"; \
			failed=1; \
		else \
			echo "\033[32mPASSED: $$tb\033[0m"; \
		fi; \
		echo ""; \
	done; \
	if [ $$failed -eq 1 ]; then \
		echo "\033[31mSome testbenches failed!\033[0m"; \
		exit 1; \
	else \
		echo "\033[32mAll testbenches passed!\033[0m"; \
	fi

# Pattern rule for building individual testbenches
$(OUT_DIR)/%_tb_sim: $(TB_DIR)/%_tb.sv $(TB_UTILS) $(SRCS)
	@mkdir -p $(BUILD_DIR)/$(basename $(notdir $@))
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(basename $(notdir $<)) \
		--Mdir $(BUILD_DIR)/$(basename $(notdir $@)) \
		-o $(basename $(notdir $@)) \
		$(SRCS) $<
	cp $(BUILD_DIR)/$(basename $(notdir $@))/$(basename $(notdir $@)) $@

# Create new testbench from template
new_tb:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make new_tb name=<testbench_name>"; \
		exit 1; \
	fi
	m4 -D M4__TB_NAME="$(name)_tb" $(TB_DIR)/tb_template.sv.m4 > $(TB_DIR)/$(name)_tb.sv

# ===========================
# RISCOF
# ===========================
$(RISCOF_DUT_BIN): $(SRCS) $(RISCOF_DUT_SRC)
	@mkdir -p $(BUILD_DIR)/riscof
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module dut \
		--Mdir $(BUILD_DIR)/riscof \
		-o dut_sim \
		$(SRCS) $(RISCOF_DUT_SRC)
	cp $(BUILD_DIR)/riscof/dut_sim $(RISCOF_DUT_BIN)

$(RISCOF_CONFIG): $(RISCOF_CONFIG_TEMPLATE)
	m4 -D M4__WORKSPACE_PATH="$(PWD)" $< > $@

riscof_build_dut: $(RISCOF_DUT_BIN)

riscof_validateyaml: $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) && riscof validateyaml --config=config.ini

riscof_clone_archtest: $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) && riscof arch-test --clone

riscof_generate_testlist: $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) && \
		riscof testlist --config=config.ini \
		--suite=riscv-arch-test/riscv-test-suite/ \
		--env=riscv-arch-test/riscv-test-suite/env

riscof_run: $(RISCOF_CONFIG) riscof_build_dut
	cd $(RISCOF_DIR) && \
		riscof run --config=config.ini \
		--suite=riscv-arch-test/riscv-test-suite/ \
		--env=riscv-arch-test/riscv-test-suite/env

# ===========================
# Linting
# ===========================
svlint:
	bash -o pipefail -c 'svlint $(if $(CI),--github-actions) $(SRCS) $(if $(CI),| sed "s/::error/::warning/g")'

svlint_tb:
	bash -o pipefail -c 'svlint $(if $(CI),--github-actions) $(TB_SRCS) $(if $(CI),| sed "s/::error/::warning/g")'

.PHONY: all run svlint svlint_tb build_top run_top build_tb run_tb new_tb
