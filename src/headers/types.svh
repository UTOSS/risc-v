`ifndef TYPES_VH
`define TYPES_VH

/* defines the bitness of the processor */
`define PROCESSOR_BITNESS 32
`define NUMBER_OF_CSRS 4096
`define CSR_RF_WIDTH $clog2(`NUMBER_OF_CSRS)

typedef logic [`PROCESSOR_BITNESS -1:0] instr_t;
typedef logic [`PROCESSOR_BITNESS -1:0] addr_t;
typedef logic [`PROCESSOR_BITNESS -1:0] imm_t;
typedef logic [`PROCESSOR_BITNESS -1:0] data_t;
typedef logic [4:0] reg_t;
typedef logic [`CSR_RF_WIDTH -1:0] csr_addr_t;


// Opcodes
// Section 36.1. RV32/64G Instruction Set Listings: Table 1. RISC-V base opcode map, inst[1:0]=11
typedef enum logic [6:0]
    { OPCODE_OP        = 7'b0110011 //R-type
    , OPCODE_OP_IMM    = 7'b0010011 //I-type logic
    , OPCODE_LOAD      = 7'b0000011 //I-type load
    , OPCODE_STORE     = 7'b0100011 //S-type
    , OPCODE_BRANCH    = 7'b1100011 //B-type
    , OPCODE_JAL       = 7'b1101111 //J-type
    , OPCODE_JALR      = 7'b1100111 //I-type jump
    , OPCODE_AUIPC     = 7'b0010111 //U-type
    , OPCODE_LUI       = 7'b0110111 //U-type
    , OPCODE_MISC_MEM  = 7'b0001111 //FENCE
    , OPCODE_SYSTEM    = 7'b1110011 //SYSTEM
    , OPCODE_AMO       = 7'b0101111 //R-type, A extension (LR/SC/AMO)
    } opcode_t;


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

// NOTE on the encoding: `RESULT_SRC__ATOMIC` deliberately has bit 0 set, matching
// `RESULT_SRC__READ_DATA`. Both name instructions whose result is produced in the memory stage, so
// a dependent instruction behind them cannot be served by forwarding alone and has to stall. The
// hazard unit does not exploit that yet -- `lw_stall` in src/hazard_unit.sv compares against
// `RESULT_SRC__READ_DATA` for equality -- but keeping the property means the stall condition can
// later become a bit test that covers atomics without the hazard unit knowing the A extension
// exists. Preserve it if you renumber these.
typedef enum logic [2:0]
  { RESULT_SRC__ALU_RESULT = 3'b000
  , RESULT_SRC__READ_DATA  = 3'b001
  , RESULT_SRC__PC_PLUS_4  = 3'b010

  // result is produced by the A extension's memory-stage FSM: the loaded word for `lr.w`, the
  // success/failure code for `sc.w`, or the pre-modification value for an AMO
  , RESULT_SRC__ATOMIC     = 3'b011
  , RESULT_SRC__CSR_READ   = 3'b100
  } result_src_t;

// what the memory stage is being asked to do with the instruction in flight
//
// this supersedes the single `mem_write` bit, which could only distinguish "store" from
// "everything else" -- not enough once an instruction can ask for a read-modify-write sequence
typedef enum logic [1:0]
  { MEM_OP__NONE   = 2'b00
  , MEM_OP__READ   = 2'b01
  , MEM_OP__WRITE  = 2'b10

  // read-modify-write sequence driven by the A extension's memory-stage FSM
  , MEM_OP__ATOMIC = 2'b11
  } mem_op_t;

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
