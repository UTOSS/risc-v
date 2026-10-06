TOPLEVEL_LANG := verilog
SIM ?= verilator # Default simulator is verilator, but can be overridden with SIM=...
TOPLEVEL := alu_dut # The name of the top-level module to be tested
MODULE := test_alu
export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

VERILOG_SOURCES := $(abspath alu_dut.sv) \
                   $(abspath ../src/modules/ALU_ALUdecoder/ALU.sv)
COMPILE_ARGS += -I$(abspath ..)

include $(shell cocotb-config --makefiles)/Makefile.sim
