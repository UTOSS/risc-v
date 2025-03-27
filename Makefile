SRC_DIR  := src
OUTPUT 	 := out/top.vvp
IVERILOG := iverilog
VVP 		 := vvp

all: $(OUTPUT)

$(OUTPUT): $(SRCS)
	$(IVERILOG) -g2012 -o $(OUTPUT) -c src/top.cf

run: $(OUTPUT)
	$(VVP) $(OUTPUT)

# tmp
fetch_tb:
	$(IVERILOG) -g2012 -o $(OUTPUT) $(SRCS) -c src/top.cf test/fetch_tb.sv

.PHONY: all run
