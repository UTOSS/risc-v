SRC_DIR  := src
TB_DIR   := test
OUTPUT 	 := out/top.vvp
IVERILOG := iverilog
VVP 		 := vvp

SRCS := $(shell find $(SRC_DIR) -name "*.sv" -o -name "*.v")

TB_SRC_PATTERN := test/%_tb.sv
TB_OUT_PATTERN := out/%_tb.vvp

TB_SRCS := $(wildcard $(subst %,*,$(TB_SRC_PATTERN)))
TB_VVPS := $(patsubst $(TB_SRC_PATTERN),$(TB_OUT_PATTERN),$(TB_SRCS))
TB_UTILS := test/utils.svh

TB_VCD_BASE_PATH := test/vcd

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

build_tb: $(TB_VVPS)

run_tb: $(TB_VVPS)
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

svlint:
	svlint $(if $(CI),--github-actions) $(SRCS) $(if $(CI),| sed 's/::error/::warning/g')

svlint_tb:
	svlint $(if $(CI),--github-actions) $(TB_SRCS) $(if $(CI),| sed 's/::error/::warning/g')

.PHONY: all run svlint svlint_tb build_top run_top build_tb run_tb new_tb
