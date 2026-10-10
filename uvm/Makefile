VERILATOR ?= verilator
JOBS ?= 8
UTOSS_RISCV_CONFIG ?= RV32IZicsr
UVM_HOME ?= /opt/uvm/1800.2-2020.3.1/src
REPO_ROOT := $(abspath ..)
BUILD_DIR := build
ALU_BIN := $(BUILD_DIR)/alu/Valu_uvm_top
CORE_BIN := $(BUILD_DIR)/ecall/Vcore_uvm_top
ROOT_MAKE := $(MAKE) -s --no-print-directory -C $(REPO_ROOT)
CORE_SRCS := $(addprefix $(REPO_ROOT)/,$(shell $(ROOT_MAKE) print_srcs ENV=simulation UTOSS_RISCV_CONFIG=$(UTOSS_RISCV_CONFIG)))
CORE_SRCS := $(filter-out $(REPO_ROOT)/envs/simulation/top_tb.sv,$(CORE_SRCS))

ifeq ($(strip $(UVM_HOME)),)
$(error UVM_HOME is not set; use the devcontainer with Accellera UVM installed)
endif
ifeq ($(wildcard $(UVM_HOME)/uvm_pkg.sv),)
$(error Cannot find $(UVM_HOME)/uvm_pkg.sv; UVM_HOME must point to UVM's src directory)
endif
ifneq ($(MAKECMDGOALS),run-alu)
ifeq ($(findstring Zicsr,$(UTOSS_RISCV_CONFIG)),)
$(error The full-core UVM tests require Zicsr, e.g. UTOSS_RISCV_CONFIG=RV32IZicsr)
endif
endif

COMMON_FLAGS := --binary --timing -j $(JOBS) -sv -Wno-fatal \
	+define+UVM_NO_DPI +incdir+$(UVM_HOME) +incdir+$(REPO_ROOT) \
	-Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-TIMESCALEMOD -I$(REPO_ROOT)

.PHONY: all run run-alu run-ecall clean
all: $(ALU_BIN) $(CORE_BIN)

$(ALU_BIN): Makefile alu/alu_uvm.sv $(REPO_ROOT)/src/modules/ALU_ALUdecoder/ALU.sv $(UVM_HOME)/uvm_pkg.sv
	mkdir -p $(BUILD_DIR)/alu
	$(VERILATOR) $(COMMON_FLAGS) --top-module alu_uvm_top --Mdir $(BUILD_DIR)/alu \
		-o Valu_uvm_top $(UVM_HOME)/uvm_pkg.sv \
		$(REPO_ROOT)/src/modules/ALU_ALUdecoder/ALU.sv alu/alu_uvm.sv

$(CORE_BIN): Makefile core/ecall_uvm.sv $(CORE_SRCS) $(UVM_HOME)/uvm_pkg.sv
	mkdir -p $(BUILD_DIR)/ecall
	$(VERILATOR) $(COMMON_FLAGS) +define+UTOSS_RISCV__ZICSR_ENABLED \
		--top-module core_uvm_top --Mdir $(BUILD_DIR)/ecall \
		-o Vcore_uvm_top $(UVM_HOME)/uvm_pkg.sv $(CORE_SRCS) core/ecall_uvm.sv

run: run-alu run-ecall

run-alu: $(ALU_BIN)
	./$(ALU_BIN) +UVM_TESTNAME=alu_smoke_test

run-ecall: $(CORE_BIN)
	./$(CORE_BIN) +UVM_TESTNAME=ecall_smoke_test
	./$(CORE_BIN) +UVM_TESTNAME=ecall_relocated_test
	./$(CORE_BIN) +UVM_TESTNAME=ecall_wrong_path_test
	./$(CORE_BIN) +UVM_TESTNAME=ecall_decode_negative_test

clean:
	python3 -c 'import shutil; shutil.rmtree("$(BUILD_DIR)", ignore_errors=True)'
