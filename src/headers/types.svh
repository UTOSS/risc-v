`ifndef TYPES_VH
`define TYPES_VH

/* defines the bitness of the processor */
`define PROCESSOR_BITNESS 32

typedef logic [`PROCESSOR_BITNESS -1:0] instr_t;
typedef logic [`PROCESSOR_BITNESS -1:0] addr_t;
typedef logic [`PROCESSOR_BITNESS -1:0] imm_t;
typedef logic [`PROCESSOR_BITNESS -1:0] data_t;
typedef logic [11:0] csr_addr_t;

typedef logic [6:0] opcode_t;

// high-level ALU operation
// based on table 7.2 of digital design and computer architecture book
typedef enum logic [1:0]
  { ALU_OP__ADD                = 2'b00
  , ALU_OP__BRANCH             = 2'b01
  , ALU_OP__REGISTER_OPERATION = 2'b10

  // default value to use when alu op is not to be relied on
  , ALU_OP__UNSET              = 2'b11
  } alu_op_t;

// low-level ALU operation
typedef enum logic [3:0]
  { ALU_CONTROL_ADD  = 4'b0000
  , ALU_CONTROL_SUB  = 4'b0001
  , ALU_CONTROL_SLL  = 4'b0010
  , ALU_CONTROL_SLT  = 4'b0011
  , ALU_CONTROL_SLTU = 4'b0100
  , ALU_CONTROL_XOR  = 4'b0101
  , ALU_CONTROL_SRL  = 4'b0110
  , ALU_CONTROL_SRA  = 4'b0111
  , ALU_CONTROL_OR   = 4'b1000
  , ALU_CONTROL_AND  = 4'b1001
  } alu_control_t;

typedef enum logic [0:0]
  { ALU_SRC_A__RD1 = 1'b0
  , ALU_SRC_A__PC  = 1'b1
  } alu_src_a_t;

typedef enum logic [0:0]
  { ALU_SRC_B__RD2     = 1'b0
  , ALU_SRC_B__IMM_EXT = 1'b1
  } alu_src_b_t;

// represents the possible input sources of the address for memory access as selected by the Control
// FSM; See Figure 7.22 of the digital disgn and computer architecture book
typedef enum logic
  { ADR_SRC__PC     = 1'b0
  , ADR_SRC__RESULT = 1'b1
  } adr_src_t;

typedef enum logic [1:0]
  { RESULT_SRC__ALU_RESULT = 2'b00
  , RESULT_SRC__READ_DATA  = 2'b01
  , RESULT_SRC__PC_PLUS_4  = 2'b10
  , RESULT_SRC__CSR_READ   = 2'b11
  } result_src_t;

typedef enum logic
  { PC_SRC__INCREMENT  = 1'b0
  , PC_SRC__ALU_RESULT = 1'b1
  } pc_src_t;

typedef enum logic
  { PC_TARGET_KIND__RELATIVE
  , PC_TARGET_KIND__ABSOLUTE
  } pc_target_kind_t;

typedef enum logic [1:0]
  { HAZARD_FORWARD_A__EXECUTE_RD1       = 2'b00
  , HAZARD_FORWARD_A__WRITE_BACK_RESULT = 2'b01
  , HAZARD_FORWARD_A__MEMORY_ALU_RESULT = 2'b10
  } hazard_forward_a_t;

typedef enum logic [1:0]
  { HAZARD_FORWARD_B__EXECUTE_RD2       = 2'b00
  , HAZARD_FORWARD_B__WRITE_BACK_RESULT = 2'b01
  , HAZARD_FORWARD_B__MEMORY_ALU_RESULT = 2'b10
  } hazard_forward_b_t;

`endif
