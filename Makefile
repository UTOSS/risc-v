SRC_DIR  := src
TB_DIR   := test
OUTPUT 	 := out/top.vvp
IVERILOG := /opt/iverilog-12/bin/iverilog
VVP 		 := /opt/iverilog-12/bin/vvp

SRCS := $(shell find $(SRC_DIR) -name "*.sv" -o -name "*.v")

TB_SRC_PATTERN := test/%_tb.sv
TB_OUT_PATTERN := out/%_tb.vvp

TB_SRCS := $(wildcard $(subst %,*,$(TB_SRC_PATTERN)))
TB_VVPS := $(patsubst $(TB_SRC_PATTERN),$(TB_OUT_PATTERN),$(TB_SRCS))
TB_UTILS := test/utils.svh

TB_VCD_BASE_PATH := test/vcd

RISCOF_DIR := riscof
RISCOF_DUT_SRC := $(RISCOF_DIR)/dut.sv
RISCOF_DUT_VVP := $(RISCOF_DIR)/dut.vvp
RISCOF_CONFIG_TEMPLATE := $(RISCOF_DIR)/config.ini.m4
RISCOF_CONFIG := $(RISCOF_DIR)/config.ini

print_srcs:
	@echo $(SRCS)

print_tb_srcs:
	@echo $(TB_SRCS)

build_top: $(OUTPUT)

run_top: $(OUTPUT)
	$(VVP) $(OUTPUT)

$(OUTPUT): $(SRCS)
	$(IVERILOG) -g2012 -o $(OUTPUT) $(SRCS)

$(TB_OUT_PATTERN): $(TB_SRC_PATTERN) $(TB_UTILS) $(SRCS)
	$(IVERILOG) -g2012 -o $@ $(SRCS) $<

new_tb:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make new_tb name=<testbench_name>"; \
		exit 1; \
	fi
	m4 -D M4__TB_NAME="$(name)_tb" test/tb_template.sv.m4 > test/$(name)_tb.sv

build_tb: $(TB_VVPS) $(TB_SRCS) $(TB_UTILS) $(SRCS)

run_tb: build_tb
	@failed=0;                                                \
	for tb in $(TB_VVPS); do                                  \
		echo "Running $$tb...";                                 \
		if ! $(VVP) -N $$tb +VCD_PATH=$(TB_VCD_BASE_PATH); then \
			echo "\033[31mFAILED: $$tb\033[0m";                   \
			failed=1;                                             \
		else                                                    \
			echo "\033[32mPASSED: $$tb\033[0m";                   \
		fi;                                                     \
		echo "";                                                \
	done;                                                     \
	if [ $$failed -eq 1 ]; then                               \
		echo "\033[31mSome testbenches failed!\033[0m";         \
		exit 1;                                                 \
	else                                                      \
		echo "\033[32mAll testbenches passed!\033[0m";          \
	fi

$(RISCOF_DUT_VVP): $(SRCS) $(RISCOF_DUT_SRC)
	$(IVERILOG) -g2012 -o $(RISCOF_DUT_VVP) $(SRCS) $(RISCOF_DUT_SRC)

$(RISCOF_CONFIG): $(RISCOF_CONFIG_TEMPLATE)
	m4 -D M4__WORKSPACE_PATH="$(PWD)" $< > $@

riscof_build_dut: $(RISCOF_DUT_VVP)

riscof_validateyaml: $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) && riscof validateyaml --config=config.ini

riscof_clone_archtest: $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) && riscof arch-test --clone

riscof_generate_testlist: $(RISCOF_CONFIG)
	cd $(RISCOF_DIR) &&                             \
		riscof testlist                               \
			--config=config.ini                         \
			--suite=riscv-arch-test/riscv-test-suite/   \
			--env=riscv-arch-test/riscv-test-suite/env

riscof_run: $(RISCOF_CONFIG) riscof_build_dut
	cd $(RISCOF_DIR) &&                             \
		riscof run                                    \
			--config=config.ini                         \
			--suite=riscv-arch-test/riscv-test-suite/   \
			--env=riscv-arch-test/riscv-test-suite/env

svlint:
	svlint $(if $(CI),--github-actions) $(SRCS) $(if $(CI),| sed 's/::error/::warning/g')

svlint_tb:
	svlint $(if $(CI),--github-actions) $(TB_SRCS) $(if $(CI),| sed 's/::error/::warning/g')

.PHONY: all run svlint svlint_tb build_top run_top build_tb run_tb new_tb
