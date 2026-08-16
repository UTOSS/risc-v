`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/timescale.svh"

module Instruction_Decode
  ( input wire [31:0] instr
  , output opcode_t opcode
  , output alu_control_t ALUControl
  , output imm_t imm_ext
  , output reg [2:0] funct3
  , output reg_t rd
  , output reg_t rs1
  , output reg_t rs2
`ifdef UTOSS_RISCV_ENABLE_B_EXT
  , output ext__b__types::b_alu_control_t b_alu_control
`endif
  );

  alu_op_t alu_op;
  alu_control_t base_alu_control;
  logic [6:0] funct7;

  assign opcode = opcode_t'(instr[6:0]);

  // combinational logic for extracting funct3 and funct7 for ALU decoder input
  always_comb
    case (opcode)
      OPCODE_OP, OPCODE_OP_IMM: funct3 = instr[14:12];
      OPCODE_LOAD, OPCODE_STORE, OPCODE_BRANCH: funct3 = instr[14:12];
      default: funct3 = 3'b000;
    endcase

  always_comb
    case (opcode)
      OPCODE_OP, OPCODE_OP_IMM: funct7 = instr[31:25];
      default: funct7 = 7'b0;
    endcase

  // determine ALU op based on opcode
  always_comb
    case (opcode)
      OPCODE_OP:       alu_op = ALU_OP__REGISTER_OPERATION;
      OPCODE_LOAD:     alu_op = ALU_OP__ADD;
      OPCODE_JALR:     alu_op = ALU_OP__ADD;
      OPCODE_STORE:    alu_op = ALU_OP__ADD;
      OPCODE_BRANCH:   alu_op = ALU_OP__BRANCH;
      OPCODE_AUIPC:    alu_op = ALU_OP__ADD;
      OPCODE_LUI:      alu_op = ALU_OP__ADD;
      OPCODE_MISC_MEM: alu_op = ALU_OP__UNSET;
      default:         alu_op = ALU_OP__UNSET;
    endcase

  always_comb
    case (opcode)
      OPCODE_OP
    , OPCODE_OP_IMM
    , OPCODE_LOAD
    , OPCODE_JALR
    , OPCODE_AUIPC
    , OPCODE_LUI
    , OPCODE_JAL: rd = instr[11:7];
      default: rd = 5'b00000;
    endcase

  always_comb
    case (opcode)
      OPCODE_OP: rs1 = instr[19:15];
      OPCODE_OP_IMM, OPCODE_LOAD, OPCODE_JALR: rs1 = instr[19:15];
      OPCODE_STORE, OPCODE_BRANCH: rs1 = instr[19:15];
      default: rs1 = 5'b00000;
    endcase

  always_comb
    case (opcode)
      OPCODE_OP: rs2 = instr[24:20];
      OPCODE_OP_IMM, OPCODE_LOAD, OPCODE_JALR: rs2 = instr[24:20];
      OPCODE_STORE, OPCODE_BRANCH: rs2 = instr[24:20];
      default: rs2 = 5'b00000;
    endcase


  // immediate decode
  always_comb
    case (opcode)
      OPCODE_OP_IMM:  imm_ext = {{20{instr[31]}}, instr[31:20]};
      OPCODE_LOAD:    imm_ext = {{20{instr[31]}}, instr[31:20]};
      OPCODE_JALR:    imm_ext = {{20{instr[31]}}, instr[31:20]};
      OPCODE_STORE:   imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      OPCODE_BRANCH:  imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
      OPCODE_JAL:     imm_ext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
      OPCODE_AUIPC:   imm_ext = {instr[31:12], 12'h000};
      OPCODE_LUI:     imm_ext = {instr[31:12], 12'h000};
      default:        imm_ext = 32'b0;
    endcase

  ALUdecoder instanceALUDec
    ( .funct3      ( funct3           )
    , .funct7      ( funct7           )
    , .alu_op      ( alu_op           )
    , .alu_control ( base_alu_control )
    );

`ifdef UTOSS_RISCV_ENABLE_B_EXT
  ext__b__decoder instanceBExtDec
    ( .funct3        ( funct3           )
    , .funct7        ( funct7           )
    , .opcode        ( opcode           )
    , .rd            ( rd               )
    , .rs2           ( rs2              )
    , .b_alu_control ( b_alu_control    )
    );
`endif

  assign ALUControl = base_alu_control;

endmodule
