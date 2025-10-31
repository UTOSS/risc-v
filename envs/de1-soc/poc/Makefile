RISCV_PREFIX := riscv32-unknown-elf
RISCV_GCC := $(RISCV_PREFIX)-gcc
RISCV_OBJCOPY := $(RISCV_PREFIX)-objcopy

all: poc.mem

poc.elf: poc.c link.ld
	$(RISCV_GCC) -march=rv32i -mabi=ilp32 -mno-relax \
		-static -mcmodel=medany -fvisibility=hidden \
		-nostdlib -nostartfiles -g \
		-T link.ld \
		poc.c \
		-o $@

poc.mem: poc.elf
	$(RISCV_OBJCOPY) -O verilog --verilog-data-width=4 $< $@

clean:
	rm poc.elf poc.mem

.PHONY: clean
