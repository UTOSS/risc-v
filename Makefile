SRC_DIR  := src
SRCS 		 := $(shell find $(SRC_DIR) -type f \( -name "*.sv" -o -name "*.svh" -o -name "*.v" -o -name "*.vh" \))
OUTPUT 	 := out/top.vvp
IVERILOG := iverilog
VVP 		 := vvp

all: $(OUTPUT)

$(OUTPUT): $(SRCS)
	$(IVERILOG) -g2012 -o $(OUTPUT) $(SRCS)

run: $(OUTPUT)
	$(VVP) $(OUTPUT)

# tmp
fetch_tb:
	$(IVERILOG) -g2012 -o $(OUTPUT) $(SRCS) test/fetch_tb.sv

.PHONY: all run
