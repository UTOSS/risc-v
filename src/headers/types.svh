`ifndef TYPES_VH
`define TYPES_VH

/* defines the bitness of the processor */
`define PROCESSOR_BITNESS 32

typedef logic [`PROCESSOR_BITNESS -1:0] instr_t;
typedef logic [`PROCESSOR_BITNESS -1:0] addr_t;
typedef logic [`PROCESSOR_BITNESS -1:0] imm_t;
typedef logic [`PROCESSOR_BITNESS -1:0] data_t;

typedef logic [6:0] opcode_t;

// based on table 7.2 of digital design and computer architecture book
typedef enum logic [1:0]
  { ALU_OP__ADD                = 2'b00
  , ALU_OP__BRANCH             = 2'b01
  , ALU_OP__REGISTER_OPERATION = 2'b10

  // default value to use when alu op is not to be relied on
  , ALU_OP__UNSET              = 2'b11
  } alu_op_t;

// represents the possible input sources for the first operand of the ALU as selected by the Control
// FSM; See Figure 7.46 of digital design and computer architecture book
typedef enum logic [1:0]
  { ALU_SRC_A__PC     = 2'b00
  , ALU_SRC_A__OLD_PC = 2'b01
  , ALU_SRC_A__RD1    = 2'b10
  , ALU_SRC_A__ZERO   = 2'b11

  , ALU_SRC_A__UNSET  = 2'bxx
  } alu_src_a_t;

// represents the possible input sources for the second operand of the ALU as selected by the
// Control FSM; See Figure 7.46 of digital design and computer architecture book
typedef enum logic [1:0]
  { ALU_SRC_B__RD2     = 2'b00
  , ALU_SRC_B__IMM_EXT = 2'b01
  , ALU_SRC_B__4       = 2'b10

  , ALU_SRC_B__UNSET = 2'b11
  } alu_src_b_t;

typedef enum logic [0:0]
  { EXECUTE_ALU_SRC_B__RD2     = 1'b0
  , EXECUTE_ALU_SRC_B__IMM_EXT = 1'b1
  } execute_alu_src_b_t;

// represents the possible input sources of the address for memory access as selected by the Control
// FSM; See Figure 7.22 of the digital disgn and computer architecture book
typedef enum logic
  { ADR_SRC__PC     = 1'b0
  , ADR_SRC__RESULT = 1'b1
  } adr_src_t;

// represents the possible sources of the result fed into PC, RF, or memory as selected by the
// Control FSM; See Figure 7.46 of the digital design and computer architecture book
// TODO: remove after pipelining integration is complete
typedef enum logic [1:0]
  { RESULT_SRC__ALU_OUT    = 2'b00
  , RESULT_SRC__DATA       = 2'b01
  , RESULT_SRC__ALU_RESULT = 2'b10
  } result_src_t;

typedef enum logic [1:0]
  { WRITE_BACK_RESULT_SRC__ALU_RESULT = 2'b00
  , WRITE_BACK_RESULT_SRC__READ_DATA  = 2'b01
  , WRITE_BACK_RESULT_SRC__PC_PLUS_4  = 2'b10
  } write_back_result_src_t;

typedef enum logic [1:0]
  { PC_SRC__INCREMENT = 2'b00
  , PC_SRC__JUMP      = 2'b01
  , PC_SRC__ALU_RESULT = 2'b10
  } pc_src_t;

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
