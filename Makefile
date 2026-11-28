# ===========================
# Directories and tools
# ===========================
SRC_DIR      := src
ENVS_DIR     := envs
TEST_DIR     := test
TB_DIR       := $(TEST_DIR)/sv
TB_OUT_DIR   := $(TB_DIR)/out
TB_BUILD_DIR := $(TB_DIR)/build
BENCHMARKS_DIR := benchmarks
INFRA_DIR    := infra
CHECKS_DIR   := checks
SVLINT_CONFIG := $(CHECKS_DIR)/svlint.toml
VERILATOR    := verilator

ENV          := simulation
TOP_OUT_DIR  := $(ENVS_DIR)/$(ENV)/out
TOP_BUILD_DIR := $(ENVS_DIR)/$(ENV)/build

RISCOF_DIR           := $(TEST_DIR)/riscof
RISCOF_BUILD_DIR     := $(RISCOF_DIR)/build
RISCOF_DUT_SRC       := $(RISCOF_DIR)/dut.sv
RISCOF_DUT_BIN       := $(RISCOF_DIR)/dut_sim
RISCOF_CONFIG_TEMPLATE := $(RISCOF_DIR)/config.ini.m4
RISCOF_CONFIG        := $(RISCOF_DIR)/config.ini

RISCOF_UTOSS_RISCV_ISA_CONFIG_TEMPLATE := $(RISCOF_DIR)/utoss_riscv/utoss_riscv_isa.yaml.m4
RISCOF_UTOSS_RISCV_ISA_CONFIG          := $(RISCOF_DIR)/utoss_riscv/utoss_riscv_isa.yaml

MCY_DIR      := $(TEST_DIR)/mcy
PYUVM_DIR    := $(TEST_DIR)/PyUVM

# =============
# Build config
# =============

# Canonical RISC-V ISA specification format (e.g. RV32I, RV32IZbb_Zbkb, RV32IZicsr)
UTOSS_RISCV_CONFIG ?= $(if $(RISCOF_ISA_STRING),$(RISCOF_ISA_STRING),RV32I)
RISCOF_ISA_STRING  := $(UTOSS_RISCV_CONFIG)


UTOSS_BOOT_ADDR ?= 32\'h0000_0000

# Generate misa value
MISA_VALUE = 0x40000100

ifneq ($(findstring C,$(UTOSS_RISCV_CONFIG)),)
MISA_VALUE := $(shell printf "0x%x" $$(( $(MISA_VALUE) | 0x4 )))
endif

ifneq ($(findstring M,$(UTOSS_RISCV_CONFIG)),)
MISA_VALUE := $(shell printf "0x%x" $$(( $(MISA_VALUE) | 0x1000 )))
endif

ifneq ($(findstring A,$(UTOSS_RISCV_CONFIG)),)
MISA_VALUE := $(shell printf "0x%x" $$(( $(MISA_VALUE) | 0x1 )))
endif

UTOSS_RISCV_VERILATOR_DEFINES := \
	$(if $(findstring Zbb,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV__ENABLE_B_EXT) \
	$(if $(findstring Zicsr,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV__ENABLE_ZICSR_EXT) \
	$(if $(findstring M,$(UTOSS_RISCV_CONFIG)),-DUTOSS_RISCV__ENABLE_M_EXT)
UTOSS_RISCV_RISCOF_VERILATOR_DEFINES := -DUTOSS_PIPELINE_LOGGER

# ===========================
# Verilator flags
# ===========================

VERILATOR_FLAGS := -Wall --binary --trace --timing -sv -cc -O3 \
	-CFLAGS "-Wno-unknown-warning-option" \
	$(UTOSS_RISCV_VERILATOR_DEFINES)
TOP_MODULE ?= top_tb
TOP_VERILATOR_FLAGS := $(VERILATOR_FLAGS) -GBOOT_ADDR=$(UTOSS_BOOT_ADDR) -DUTOSS_PIPELINE_LOGGER
RISCOF_VERILATOR_FLAGS := $(VERILATOR_FLAGS) -GBOOT_ADDR=$(UTOSS_BOOT_ADDR) $(UTOSS_RISCV_RISCOF_VERILATOR_DEFINES)

# Testbench-only defines
TB_DEFINES := -DTESTBENCH

# ===========================
# Sources
# ===========================
SRCS := $(sort $(shell find $(SRC_DIR) -not -path "*/build/*" \( -name "*.sv" -o -name "*.v" \))) \
        $(sort $(shell find $(ENVS_DIR)/$(ENV) -not -path "*/out/*" -not -path "*/build/*" \( -name "*.sv" -o -name "*.v" \)))

TB_SRCS := $(wildcard $(TB_DIR)/*_tb.sv)
TB_UTILS := $(TB_DIR)/utils.svh
TB_BINS := $(patsubst $(TB_DIR)/%_tb.sv, $(TB_OUT_DIR)/%_tb_sim, $(TB_SRCS))
TB_VCD_BASE_PATH := $(TB_DIR)/vcd

# ===========================
# Default
# ===========================

FORCE: # makefile hack

all: build_top
	@echo "Build finished! Try 'make run_top' or 'make run_tb'."

print_srcs:
	@echo $(SRCS)

print_tb_srcs:
	@echo $(TB_SRCS)

print_verilator_defines:
	@echo $(UTOSS_RISCV_VERILATOR_DEFINES)

# ===========================
# Top module
# ===========================
build_top: $(TOP_OUT_DIR)/top_sim

run_top: $(TOP_OUT_DIR)/top_sim
	./$<

$(TOP_OUT_DIR)/top_sim: $(SRCS)
	@mkdir -p $(TOP_OUT_DIR)
	@mkdir -p $(TOP_BUILD_DIR)/top
	$(VERILATOR) $(TOP_VERILATOR_FLAGS) \
		--top-module $(TOP_MODULE) \
		--Mdir $(TOP_BUILD_DIR)/top \
		-o top_sim \
		$(SRCS)
	cp $(TOP_BUILD_DIR)/top/top_sim $@

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
$(TB_OUT_DIR)/%_tb_sim: $(TB_DIR)/%_tb.sv $(TB_UTILS) $(SRCS)
	@mkdir -p $(TB_OUT_DIR)
	@mkdir -p $(TB_BUILD_DIR)/$(basename $(notdir $@))
	$(VERILATOR) $(VERILATOR_FLAGS) $(TB_DEFINES) \
		--top-module $(basename $(notdir $<)) \
		--Mdir $(TB_BUILD_DIR)/$(basename $(notdir $@)) \
		-o $(basename $(notdir $@)) \
		$(SRCS) $<
	cp $(TB_BUILD_DIR)/$(basename $(notdir $@))/$(basename $(notdir $@)) $@

# ===========================
# MCY mutation testing
# ===========================
MCY_SEED ?=
MCY_SIZE ?= 50 # Number of mutations to run
MCY_TOP ?= top # Name of top module

# List of tb files to check against. By default, uses all files in test/sv/
MCY_TESTS ?=

# List of files to mutate. By default, uses all files in src/
# Note that files that are not reachable by MCY_TOP are automatically ignored.
MCY_FILES ?=

mcy:
	m4 -D M4__MCY_SEED="$(MCY_SEED)" -D M4__MCY_SIZE="$(MCY_SIZE)" \
		-D M4__MCY_TOP="$(MCY_TOP)" -D M4__MCY_TESTS="$(MCY_TESTS)" \
		-D M4__MCY_DEFINES="$(strip $(UTOSS_RISCV_VERILATOR_DEFINES))" $(MCY_DIR)/config.mcy.m4 > $(MCY_DIR)/config.mcy
	cd $(MCY_DIR) && mcy purge && MCY_FILES="$(MCY_FILES)" mcy init && mcy run

# ===========================
# PyUVM verification
# ===========================
.PHONY: test_pyuvm
test_pyuvm:
	cd $(PYUVM_DIR) && PYTHONPATH="$(CURDIR)/$(PYUVM_DIR)" python3 -m pytest --import-mode=importlib tests
	$(MAKE) -C $(PYUVM_DIR) MODULE=test_alu
	$(MAKE) -C $(PYUVM_DIR) MODULE=test_ecall UTOSS_RISCV_CONFIG=RV32IZicsr

# ===========================
# Create new testbench
# ===========================
new_tb:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make new_tb name=<testbench_name>"; \
		exit 1; \
	fi
	m4 -D M4__TB_NAME="$(name)_tb" $(TB_DIR)/tb_template.sv.m4 > $(TB_DIR)/$(name)_tb.sv

# ===========================
# RISCOF
# ===========================
$(RISCOF_DUT_BIN): $(SRCS) $(RISCOF_DUT_SRC) FORCE
	@mkdir -p $(RISCOF_BUILD_DIR)
	$(VERILATOR) $(RISCOF_VERILATOR_FLAGS) \
		--top-module dut \
		--Mdir $(RISCOF_BUILD_DIR) \
		-o dut_sim \
		$(SRCS) $(RISCOF_DUT_SRC)
	cp $(RISCOF_BUILD_DIR)/dut_sim $(RISCOF_DUT_BIN)

$(RISCOF_CONFIG): $(RISCOF_CONFIG_TEMPLATE)
	m4 -D M4__WORKSPACE_PATH="$(PWD)" $< > $@

$(RISCOF_UTOSS_RISCV_ISA_CONFIG): $(RISCOF_UTOSS_RISCV_ISA_CONFIG_TEMPLATE) FORCE
	m4 \
-D M4__ISA_STRING="$(RISCOF_ISA_STRING)" \
-D M4__MISA_VALUE="$(MISA_VALUE)" \
$< > $@

riscof_build_dut: $(RISCOF_DUT_BIN)

riscof_validateyaml: $(RISCOF_UTOSS_RISCV_ISA_CONFIG) $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) && riscof validateyaml --config=config.ini

riscof_clone_archtest: $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) && riscof arch-test --clone

riscof_generate_testlist: $(RISCOF_UTOSS_RISCV_ISA_CONFIG) $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) && \
		riscof testlist --config=config.ini \
		--suite=riscv-arch-test/riscv-test-suite/ \
		--env=riscv-arch-test/riscv-test-suite/env

riscof_run: $(RISCOF_UTOSS_RISCV_ISA_CONFIG) $(RISCOF_CONFIG) riscof_build_dut
	cd $(RISCOF_DIR) && \
		riscof testlist --config=config.ini \
		--suite=riscv-arch-test/riscv-test-suite/ \
		--env=riscv-arch-test/riscv-test-suite/env && \
		python3 utoss_riscv/prepare_riscof_testlist.py --config="$(UTOSS_RISCV_CONFIG)" --work-dir="riscof_work" && \
		riscof run --config=config.ini \
		--suite=riscv-arch-test/riscv-test-suite/ \
		--env=riscv-arch-test/riscv-test-suite/env \
		--testfile=riscof_work/test_list.yaml \
		--no-browser

include $(TEST_DIR)/utoss_riscv_dv/Makefile

# ===========================
# Benchmarks (CoreMark & Embench-IoT)
# ===========================
coremark:
	$(MAKE) -C $(BENCHMARKS_DIR)/coremark run UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)

embench:
	$(MAKE) -C $(BENCHMARKS_DIR)/embench run UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)

# sidekick image builds
GITHUB_CONTAINER_REGISTRY=ghcr.io
GITHUB_ORG_NAME=utoss
QUARTUS_IMAGE_NAME=${GITHUB_CONTAINER_REGISTRY}/${GITHUB_ORG_NAME}/quartus:latest

docker_build_quartus_image:
	docker build -f $(INFRA_DIR)/Dockerfile.quartus -t ${QUARTUS_IMAGE_NAME} .
	docker login ${GITHUB_CONTAINER_REGISTRY}
	docker push ${QUARTUS_IMAGE_NAME}

# ===========================
# Hardening
# ===========================
harden_pre_pnr:
	$(MAKE) -C envs/hardening harden_pre_pnr

harden:
	$(MAKE) -C envs/hardening harden

# ===========================
# Linting
# ===========================
svlint:
	bash -o pipefail -c 'svlint -c $(SVLINT_CONFIG) $(if $(CI),--github-actions) $(SRCS) $(if $(CI),| sed "s/::error/::warning/g")'

svlint_tb:
	bash -o pipefail -c 'svlint -c $(SVLINT_CONFIG) $(if $(CI),--github-actions) $(TB_SRCS) $(if $(CI),| sed "s/::error/::warning/g")'

# every design unit in src/ must bring in a timescale itself, so that Verilator's TIMESCALEMOD
# check does not depend on the order in which source files are passed to it
check_timescale:
	python3 $(CHECKS_DIR)/check_timescale.py $(if $(CI),--github-actions) $(SRC_DIR)

lint: svlint svlint_tb check_timescale

# ===========================
# Diagrams
# ===========================
diagrams:
	$(MAKE) -C docs diagrams

block_diagrams:
	$(MAKE) -C docs block

timing_diagrams:
	$(MAKE) -C docs timing

test_diagrams:
	$(MAKE) -C docs test


# ===========================
# Phony targets
# ===========================
.PHONY: all build_top run_top build_tb run_tb new_tb mcy \
        svlint svlint_tb check_timescale lint harden_pre_pnr harden \
        riscof_build_dut riscof_validateyaml riscof_clone_archtest \
        riscof_generate_testlist riscof_run \
        riscv_dv coremark embench \
				diagrams block_diagrams timing_diagrams test_diagrams update_diagrams update_diagrmas \
				FORCE
