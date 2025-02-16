`ifndef TYPES_VH
`define TYPES_VH

/* defines the bitness of the processor */
`define PROCESSOR_BITNESS 32

typedef logic [`PROCESSOR_BITNESS-1:0] instr_t;
typedef logic [`PROCESSOR_BITNESS-1:0] addr_t;

`endif
