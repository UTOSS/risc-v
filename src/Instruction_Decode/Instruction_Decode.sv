`include "src/params.svh"
`include "src/types.svh"

module Instruction_Decode
  ( input wire [31:0] instr
  , output opcode_t opcode
  , output wire [3:0] ALUControl
  , output imm_t imm_ext
  , output reg [2:0] funct3
  , output reg [6:0] funct7
  , output reg [4:0] rd
  , output reg [4:0] rs1
  , output reg [4:0] rs2
  );

  alu_op_t alu_op;
  alu_control_t base_alu_control;
`ifdef UTOSS_RISCV_ENABLE_B_EXT
  logic [3:0] ext_b_alu_control;
`endif

  assign opcode = instr[6:0];

  //combinational logic for extracting funct3 and funct7[5] for ALU Decoder input

  always @(*) begin

    funct3 = 3'b000;
    funct7 = 7'b0;

    case (opcode)

    RType, IType_logic: begin //R-Type

      funct3 = instr[14:12];
      funct7 = instr[31:25];

    end

    IType_load, SType, BType: begin

      funct3 = instr[14:12];

    end

    endcase
  end

  // determine ALU op based on the opcode; see Table 7.2 of the digital design and computer
  // architecture book
  always @(*) begin
    case (opcode)
      RType:      alu_op = ALU_OP__REGISTER_OPERATION;
      IType_load: alu_op = ALU_OP__ADD;
      IType_jalr: alu_op = ALU_OP__ADD; // rs1 + imm
      SType:      alu_op = ALU_OP__ADD;
      BType:      alu_op = ALU_OP__BRANCH;
      UType_auipc: alu_op = ALU_OP__ADD; // used to add 0 to imm ext
      UType_lui:   alu_op = ALU_OP__ADD; // used to add 0 to imm ext
      FENCE:     alu_op = ALU_OP__UNSET;
      default:    alu_op = ALU_OP__UNSET;

    endcase
  end

  //logic for extracting rs1, rs2, and rd registers from 32-bit instruction field
  //The logic depends on the instruction type

  always @(*) begin

    rd = 5'b00000;
    rs1 = 5'b00000;
    rs2 = 5'b00000;

    case (opcode)

        RType: begin //R-Type

        rd = instr[11:7];
        rs1 = instr[19:15];
        rs2 = instr[24:20];

      end

      IType_logic, IType_load, IType_jalr: begin //I-Type (where lw is I type)

        rd = instr[11:7];
        rs1 = instr[19:15];

      end

      SType, BType: begin //S-type and B-Type
        rs1 = instr[19:15];
        rs2 = instr[24:20];

      end

      UType_auipc, UType_lui, JType: begin
        rd = instr[11:7];
      end

      default: begin
        rd  = 5'b0;
        rs1 = 5'b0;
        rs2 = 5'b0;
      end
    endcase
  end

  // case statement for choosing 32-bit immediate format; based on opcode
    // this is essentially the extend module of the processor
  always @(*) begin
    case (opcode)
      IType_logic : imm_ext = {{20{instr[31]}}, instr[31:20]};
      IType_load  : imm_ext = {{20{instr[31]}}, instr[31:20]};
      IType_jalr : imm_ext = {{20{instr[31]}}, instr[31:20]};
      SType       : imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      BType       : imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
      JType       : imm_ext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
      UType_auipc  : imm_ext = {instr[31:12], 12'b0};
      UType_lui  : imm_ext = {instr[31:12], 12'b0};
      default:     imm_ext = 32'b0;
    endcase
  end

  //Instantiate ALU Decoder module

  ALUdecoder instanceALUDec
    ( .funct3(funct3)
    , .funct7(funct7)
    , .alu_op(alu_op)
    , .alu_control(base_alu_control)
    );

`ifdef UTOSS_RISCV_ENABLE_B_EXT
  ext__b__decoder instanceBExtDec
    ( .funct3      ( funct3           )
    , .funct7      ( funct7           )
    , .opcode      ( opcode           )
    , .rd          ( rd               )
    , .b_alu_control ( ext_b_alu_control )
    );

  assign ALUControl = (ext_b_alu_control != 4'b0000) ? ext_b_alu_control : base_alu_control;
`else
  assign ALUControl = base_alu_control;
`endif

endmodule
