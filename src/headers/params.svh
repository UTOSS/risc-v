`ifndef PARAMS_VH
`define PARAMS_VH

// Opcodes
/* verilator lint_off UNUSEDPARAM */
localparam bit [6:0] RType = 7'b0110011;
localparam bit [6:0] IType_logic = 7'b0010011;
localparam bit [6:0] IType_load = 7'b0000011;
localparam bit [6:0] SType = 7'b0100011;
localparam bit [6:0] BType = 7'b1100011;
localparam bit [6:0] JType = 7'b1101111;
localparam bit [6:0] UType_auipc = 7'b0010111;
localparam bit [6:0] UType_lui = 7'b0110111;
localparam bit [6:0] IType_jalr = 7'b1100111;
localparam bit [6:0] FENCE    = 7'b0001111;
/* verilator lint_on UNUSEDPARAM */

//ALU Operation Control Codes: Implemented as ENUM in params.svh
/*
localparam ALUAdd = 4'b0000;
localparam ALUSub = 4'b0001;
localparam ALUSLL =  4'b0010;
localparam ALUSLT = 4'b0011;
localparam ALUSLTU = 4'b0100;
localparam ALUXOR = 4'b0101;
localparam ALUSRL = 4'b0110;
localparam ALUSRA = 4'b0111;
localparam ALUOR = 4'b1000;
localparam ALUAND = 4'b1001;
*/

`endif  // PARAMS_VH
