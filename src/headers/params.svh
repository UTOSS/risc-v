`ifndef PARAMS_VH
`define PARAMS_VH

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
    } opcode_t;

//ALU Operation Control Codes: Implemented as ENUM in params.svh
/*
parameter ALUAdd = 4'b0000;
parameter ALUSub = 4'b0001;
parameter ALUSLL =  4'b0010;
parameter ALUSLT = 4'b0011;
parameter ALUSLTU = 4'b0100;
parameter ALUXOR = 4'b0101;
parameter ALUSRL = 4'b0110;
parameter ALUSRA = 4'b0111;
parameter ALUOR = 4'b1000;
parameter ALUAND = 4'b1001;
*/

`endif  // PARAMS_VH
