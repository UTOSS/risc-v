`ifndef PARAMS_VH
`define PARAMS_VH

// Opcodes
typedef enum logic [6:0]
    { OP        = 7'b0110011 //R-type
    , OP_IMM    = 7'b0010011 //I-type logic
    , LOAD      = 7'b0000011 //I-type load
    , STORE     = 7'b0100011 //S-type
    , BRANCH    = 7'b1100011 //B-type
    , JAL       = 7'b1101111 //J-type
    , JALR      = 7'b1100111 //I-type jump
    , AUIPC     = 7'b0010111 //U-type
    , LUI       = 7'b0110111 //U-type
    , MISC_MEM  = 7'b0001111 //FENCE
    } opcode_name_t;

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
