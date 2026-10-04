# pyuvm testbench for the core, simulated with Verilator via cocotb
#
#   make                          run the tests (RV32I)
#   make UTOSS_RISCV_CONFIG=...   run the tests against another core configuration
#   make MODULE=test_ecall UTOSS_RISCV_CONFIG=RV32IZicsr  run directed ECALL tests
#   make NUM_ITEMS=100            run more randomized items
#   make RANDOM_SEED=1234         reproduce a run
#   make WAVES=1                  also dump waveforms (dump.vcd)
#
# Requires pyuvm (`pip install pyuvm`) on top of cocotb.

REPO_ROOT := $(abspath ..)

UTOSS_RISCV_CONFIG ?= RV32I
export UTOSS_RISCV_CONFIG

# reuse the core sources and configuration defines from the top-level Makefile, so the core is built
# exactly as in the rest of the flow; the DUT is `top` from envs/simulation, which hooks the core up
# to its memory
ROOT_MAKE := $(MAKE) -s --no-print-directory -C $(REPO_ROOT) UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)

SIM             ?= verilator
TOPLEVEL_LANG   ?= verilog
TOPLEVEL        := top
MODULE          ?= test_add
COCOTB_RESULTS_FILE ?= results-$(MODULE)-$(UTOSS_RISCV_CONFIG).xml
VERILOG_SOURCES := $(addprefix $(REPO_ROOT)/,$(shell $(ROOT_MAKE) print_srcs ENV=simulation))

COMPILE_ARGS += -I$(REPO_ROOT) $(shell $(ROOT_MAKE) print_verilator_defines) -Wno-fatal

# cocotb's switch for Verilator waveforms: builds with tracing (including struct fields) and enables
# dumping at runtime
ifeq ($(WAVES),1)
VERILATOR_TRACE := 1
endif

# one simulator build per configuration and waveform setting, since neither is a dependency of the
# build: switching either then never reuses a stale simulator
SIM_BUILD := sim_build/$(UTOSS_RISCV_CONFIG)$(if $(filter 1,$(WAVES)),-waves)

# default target: cocotb's `sim` exits successfully even when a test fails, so fail on any failure
# recorded in the results file
.PHONY: test
test: sim
	@! grep -q "<failure" $(COCOTB_RESULTS_FILE) || (echo "ERROR: some tests failed, see above"; exit 1)

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build
