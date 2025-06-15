SRC_DIR  := src
OUTPUT 	 := out/top.vvp
IVERILOG := iverilog
VVP 		 := vvp

TB_SRC_PATTERN := test/%_tb.sv
TB_OUT_PATTERN := out/%_tb.vvp

TB_SRCS := $(wildcard $(subst %,*,$(TB_SRC_PATTERN)))
TB_VVPS := $(patsubst $(TB_SRC_PATTERN),$(TB_OUT_PATTERN),$(TB_SRCS))
TB_UTILS := test/utils.svh

TB_VCD_BASE_PATH := test/vcd

all: $(OUTPUT)

$(OUTPUT):
	$(IVERILOG) -g2012 -o $(OUTPUT) -c src/top.cf

run: $(OUTPUT)
	$(VVP) $(OUTPUT)

$(TB_OUT_PATTERN): $(TB_SRC_PATTERN) $(TB_UTILS)
	$(IVERILOG) -g2012 -o $@ -c src/top.cf $<

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

.PHONY: all run testbenches run-tests
