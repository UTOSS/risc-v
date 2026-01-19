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

// represents the possible input sources of the address for memory access as selected by the Control
// FSM; See Figure 7.22 of the digital disgn and computer architecture book
typedef enum logic
  { ADR_SRC__PC     = 1'b0
  , ADR_SRC__RESULT = 1'b1
  } adr_src_t;

// represents the possible sources of the result fed into PC, RF, or memory as selected by the
// Control FSM; See Figure 7.46 of the digital design and computer architecture book
typedef enum logic [1:0]
  { RESULT_SRC__ALU_OUT    = 2'b00
  , RESULT_SRC__DATA       = 2'b01
  , RESULT_SRC__ALU_RESULT = 2'b10
  } result_src_t;

typedef enum logic [1:0]
  { PC_SRC__INCREMENT = 2'b00
  , PC_SRC__JUMP      = 2'b01
  , PC_SRC__ALU_RESULT = 2'b10
  } pc_src_t;

// parameterize states (binary encoding)
typedef enum logic[4:0] {
  FETCH      = 5'b00000
  , DECODE     = 5'b00001
  , EXECUTER   = 5'b00010
  , UNCONDJUMP = 5'b00011
  , EXECUTEI   = 5'b00100
  , MEMADR     = 5'b00101
  , ALUWB      = 5'b00110
  , MEMWRITE   = 5'b00111
  , MEMREAD    = 5'b01000
  , MEMWB      = 5'b01001
  , BRANCHIFEQ = 5'b01010
  //new states for lui and auipc
  , LUI = 5'b01011
  , AUIPC = 5'b01100
  , JALR_CALC  = 5'b01101 // calculate rs1 + imm, store in alu_out
  , JALR_STEP2 = 5'b01110 // link and use alu_out to update PC
  // new state for remaining branch instructions
  , BRANCHCOMP = 5'b01111
  , FETCH_WAIT = 5'b10000
} state_t;

`endif
