RISCV_DV_DIR         ?= $(if $(RISCV_DV_HOME),$(RISCV_DV_HOME),$(HOME)/tools/riscv-dv)
RISCV_DV_OUT         ?= utoss_riscv_dv/logs/out_utoss_smoke
RISCV_DV_TEST        ?= utoss_rv32i_basic_smoke
RISCV_DV_TESTLIST    ?= utoss_riscv_dv/utoss_riscv_dv_smoke.yaml
RISCV_DV_SIMULATOR   ?= pyflow
RISCV_DV_MABI        ?= ilp32
RISCV_DV_ISS         ?= sail
RISCV_DV_SEED        ?=
RISCV_DV_GEN_TIMEOUT ?= 3600
RISCV_DV_ARGS        ?=

RISCV_DV_TARGET ?= $(shell printf '%s' '$(UTOSS_RISCV_CONFIG)' | tr '[:upper:]' '[:lower:]')

# Note: The provided IMCB target uses outdated instructions so will not work
RISCV_DV_ISA ?= $(shell printf '%s' '$(subst B,_Zba_Zbb_Zbc_Zbs,$(UTOSS_RISCV_CONFIG))_zicsr_zifencei' | tr '[:upper:]' '[:lower:]')

riscv_dv:
	python3 utoss_riscv_dv/utoss_riscv_dv.py \
		--repo-root . \
		--riscv-dv-dir $(RISCV_DV_DIR) \
		--output $(RISCV_DV_OUT) \
		--test $(RISCV_DV_TEST) \
		--testlist $(RISCV_DV_TESTLIST) \
		--simulator $(RISCV_DV_SIMULATOR) \
		--target $(RISCV_DV_TARGET) \
		--isa $(RISCV_DV_ISA) \
		--mabi $(RISCV_DV_MABI) \
		--iss $(RISCV_DV_ISS) \
		$(if $(RISCV_DV_SEED),--seed $(RISCV_DV_SEED)) \
		$(if $(RISCV_DV_GEN_TIMEOUT),--gen-timeout $(RISCV_DV_GEN_TIMEOUT)) \
		$(RISCV_DV_ARGS)
