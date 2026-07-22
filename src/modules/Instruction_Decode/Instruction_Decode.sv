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
  // reg [2:0] funct3;
  // reg [6:0] funct7;

  /* verilator lint_off UNUSEDSIGNAL */
  wire [3:0] state;
  /* verilator lint_on UNUSEDSIGNAL */


  logic [6:0] funct7;
  assign opcode = opcode_t'(instr[6:0]);

  //combinational logic for extracting funct3 and funct7[5] for ALU Decoder input

  /* verilator lint_off UNUSEDSIGNAL */
  reg [2:0] default_funct3;
  reg [6:0] default_funct7;
  /* verilator lint_on UNUSEDSIGNAL */
  always @(*) begin

    funct3 = 3'b000;
    funct7 = 7'b0;

    case (opcode)

    OPCODE_OP, OPCODE_OP_IMM: begin //R-Type

      funct3 = instr[14:12];
      funct7 = instr[31:25];

    end

    OPCODE_LOAD, OPCODE_STORE, OPCODE_BRANCH: begin

      funct3 = instr[14:12];

    end
    default:;
    endcase
  end

  // determine ALU op based on the opcode; see Table 7.2 of the digital design and computer
  // architecture book
  always @(*) begin
    case (opcode)
      OPCODE_OP:      alu_op = ALU_OP__REGISTER_OPERATION;
      OPCODE_LOAD: alu_op = ALU_OP__ADD;
      OPCODE_JALR: alu_op = ALU_OP__ADD; // rs1 + imm
      OPCODE_STORE:      alu_op = ALU_OP__ADD;
      OPCODE_BRANCH:      alu_op = ALU_OP__BRANCH;
      OPCODE_AUIPC: alu_op = ALU_OP__ADD; // used to add 0 to imm ext
      OPCODE_LUI:   alu_op = ALU_OP__ADD; // used to add 0 to imm ext
      OPCODE_MISC_MEM:     alu_op = ALU_OP__UNSET;
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

        OPCODE_OP: begin //R-Type

        rd = instr[11:7];
        rs1 = instr[19:15];
        rs2 = instr[24:20];

      end

      OPCODE_OP_IMM, OPCODE_LOAD, OPCODE_JALR: begin //I-Type (where lw is I type)

        rd = instr[11:7];
        rs1 = instr[19:15];
        rs2 = instr[24:20];

      end

      OPCODE_STORE, OPCODE_BRANCH: begin //S-type and B-Type
        rs1 = instr[19:15];
        rs2 = instr[24:20];

      end

      OPCODE_AUIPC, OPCODE_LUI, OPCODE_JAL: begin
        rd = instr[11:7];
      end

      default: begin
        rd  = 5'b0;
        rs1 = 5'b0;
        rs2 = 5'b0;
      end
    endcase
  end

  extend u_extend
    ( .instr   ( instr[31:7] )
    , .opcode  ( opcode      )
    , .imm_ext ( imm_ext     )
    );

  //Instantiate ALU Decoder module

  ALUdecoder instanceALUDec
    ( .funct3(funct3)
    , .funct7(funct7)
    , .alu_op(alu_op)
    , .alu_control(ALUControl)
    );


`ifdef UTOSS_RISCV_ENABLE_B_EXT
  ext__b__decoder u_ext__b__decoder
    ( .funct3        ( funct3        )
    , .funct7        ( funct7        )
    , .opcode        ( opcode        )
    , .rd            ( rd            )
    , .rs2           ( rs2           )
    , .b_alu_control ( b_alu_control )
    );
`endif

endmodule
