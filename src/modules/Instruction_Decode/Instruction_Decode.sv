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
  always_comb begin
    funct3 = 3'b000;
    funct7 = 7'b0;

    case (opcode)
      OPCODE_OP, OPCODE_OP_IMM: begin
        funct3 = instr[14:12];
        funct7 = instr[31:25];
      end

      OPCODE_LOAD, OPCODE_STORE, OPCODE_BRANCH: begin
        funct3 = instr[14:12];
      end

      default: begin
      end
    endcase
  end

  // determine ALU op based on opcode
  always_comb begin
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
  end

  // extract rd, rs1, rs2 from 32-bit instruction
  always_comb begin
    rd = 5'b00000;
    rs1 = 5'b00000;
    rs2 = 5'b00000;

    case (opcode)
      OPCODE_OP: begin
        rd = instr[11:7];
        rs1 = instr[19:15];
        rs2 = instr[24:20];
      end

      OPCODE_OP_IMM, OPCODE_LOAD, OPCODE_JALR: begin
        rd = instr[11:7];
        rs1 = instr[19:15];
        rs2 = instr[24:20];
      end

      OPCODE_STORE, OPCODE_BRANCH: begin
        rs1 = instr[19:15];
        rs2 = instr[24:20];
      end

      OPCODE_AUIPC, OPCODE_LUI, OPCODE_JAL: begin
        rd = instr[11:7];
      end

      default: begin
      end
    endcase
  end

  // immediate decode
  always_comb begin
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
  end

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
