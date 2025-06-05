`ifndef TYPES_VH
`define TYPES_VH

/* defines the bitness of the processor */
`define PROCESSOR_BITNESS 32

typedef logic [`PROCESSOR_BITNESS-1:0] instr_t;
typedef logic [`PROCESSOR_BITNESS-1:0] addr_t;
typedef logic [`PROCESSOR_BITNESS-1:0] imm_t;
typedef logic [`PROCESSOR_BITNESS-1:0] data_t;

typedef logic [6:0] opcode_t;

// based on table 7.2 of digital design and computer architecture book
typedef enum logic [1:0] {
  ALU_OP__MEMORY_ACCESS      = 2'b00,
  ALU_OP__BRANCH             = 2'b01,
  ALU_OP__REGISTER_OPERATION = 2'b10,

  // default value to use when alu op is not to be relied on
  ALU_OP__UNSET              = 2'b11
} alu_op_t;

typedef enum logic {
  PC_SRC__INCREMENT = 1'b0,
  PC_SRC__JUMP      = 1'b1
} pc_src_t;

`endif
