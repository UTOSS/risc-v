SRC_DIR  := src
OUTPUT 	 := out/top.vvp
IVERILOG := iverilog
VVP 		 := vvp

SRCS := $(SRC_DIR)/Instruction_Decode/RegisterFile.v

all: $(OUTPUT)

$(OUTPUT): $(SRCS)
	$(IVERILOG) -g2012 -o $(OUTPUT) 

run: $(OUTPUT)
	$(VVP) $(OUTPUT)

# tmp
RegFile_TB:
	$(IVERILOG) -g2012 -o $(OUTPUT) $(SRCS) src/Instruction_Decode/RegisterFile.v test/RegFile_TB.sv

.PHONY: all run