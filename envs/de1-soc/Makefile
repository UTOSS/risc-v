IVERILOG := iverilog
VVP 		 := vvp

BASE_INCLUDE_DIR=../../
CORE_SRC := $(shell find $(BASE_INCLUDE_DIR)src -name "*.sv" -o -name "*.v")
LOCAL_SRCS := $(wildcard *.sv)

all: run_tb

poc:
	$(MAKE) -C poc

top_tb.vvp: poc $(LOCAL_SRCS) $(CORE_SRC)
	$(IVERILOG) -g2012 -I$(BASE_INCLUDE_DIR) -o $@ $(LOCAL_SRCS) $(CORE_SRC)

run_tb: top_tb.vvp
	$(VVP) -N $<

.PHONY: run_tb poc
