RISCV_PREFIX  := riscv32-unknown-elf
RISCV_GCC     := $(RISCV_PREFIX)-gcc
RISCV_OBJCOPY := $(RISCV_PREFIX)-objcopy

all: poc0.mif poc1.mif poc2.mif poc3.mif

poc.elf: poc.c link.ld
	$(RISCV_GCC) -march=rv32i -mabi=ilp32 -mno-relax \
		-static -mcmodel=medany -fvisibility=hidden \
		-nostdlib -nostartfiles -g \
		-T link.ld \
		poc.c \
		-o $@

poc.mem: poc.elf
	$(RISCV_OBJCOPY) -O verilog --verilog-data-width=4 $< $@

poc0.mem poc1.mem poc2.mem poc3.mem: poc.mem
	rm -f poc0.mem poc1.mem poc2.mem poc3.mem
	@awk '/^@/ { next } \
	      { for (i = 1; i <= NF; i++) { \
	          w = $$i; \
	          print substr(w,7,2) >> "poc0.mem"; \
	          print substr(w,5,2) >> "poc1.mem"; \
	          print substr(w,3,2) >> "poc2.mem"; \
	          print substr(w,1,2) >> "poc3.mem"; \
	        } \
	      }' poc.mem

%.mif: %.mem
	@echo "Converting $< to $@..."
	@echo "WIDTH=8;" > $@
	@echo "DEPTH=512;" >> $@
	@echo "ADDRESS_RADIX=HEX;" >> $@
	@echo "DATA_RADIX=HEX;" >> $@
	@echo "CONTENT BEGIN" >> $@
	@awk 'BEGIN{addr=0} {if($$0 != "") {printf "%X : %s;\n", addr, $$0; addr++}}' $< >> $@
	@echo "END;" >> $@

clean:
	rm -f poc.elf poc.mem poc0.mif poc1.mif poc2.mif poc3.mif

.PHONY: clean
