# ALU unit tests by default; MODULE=test_ecall selects the full-core ECALL suite.
REPO_ROOT := $(abspath ..)
TOPLEVEL_LANG := verilog
SIM ?= verilator
MODULE ?= test_alu
export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

ifeq ($(MODULE),test_ecall)
UTOSS_RISCV_CONFIG ?= RV32IZicsr
export UTOSS_RISCV_CONFIG
ifeq ($(findstring Zicsr,$(UTOSS_RISCV_CONFIG)),)
$(error ECALL tests require a Zicsr configuration, e.g. UTOSS_RISCV_CONFIG=RV32IZicsr)
endif
TOPLEVEL := top
ROOT_MAKE := $(MAKE) -s --no-print-directory -C $(REPO_ROOT) UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)
VERILOG_SOURCES := $(addprefix $(REPO_ROOT)/,$(shell $(ROOT_MAKE) print_srcs ENV=simulation))
COMPILE_ARGS += $(shell $(ROOT_MAKE) print_verilator_defines) -Wno-fatal
else ifeq ($(MODULE),test_alu)
TOPLEVEL := alu_dut
VERILOG_SOURCES := $(abspath alu_dut.sv) \
                   $(REPO_ROOT)/src/modules/ALU_ALUdecoder/ALU.sv
else
$(error Unsupported MODULE=$(MODULE); choose test_alu or test_ecall)
endif
COMPILE_ARGS += -I$(REPO_ROOT)

ifeq ($(WAVES),1)
VERILATOR_TRACE := 1
endif

# Keep different DUTs, configurations and tracing settings in separate builds.
BUILD_VARIANT := $(MODULE)$(if $(filter test_ecall,$(MODULE)),-$(UTOSS_RISCV_CONFIG))$(if $(filter 1,$(WAVES)),-waves)
SIM_BUILD := sim_build/$(BUILD_VARIANT)
COCOTB_RESULTS_FILE ?= results-$(BUILD_VARIANT).xml

.PHONY: test
test: sim
	@$(PYTHON_BIN) -c 'import xml.etree.ElementTree as E; r = E.parse("$(COCOTB_RESULTS_FILE)"); assert r.findall(".//testcase"), "No tests ran"; assert not r.findall(".//failure") and not r.findall(".//error"), "PyUVM tests failed; see $(COCOTB_RESULTS_FILE)"'

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build
