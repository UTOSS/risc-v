`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

/* verilator lint_off DECLFILENAME */
module ext__b__zbkb_decoder
/* verilator lint_on DECLFILENAME */
  ( input [2:0] funct3
  , input [6:0] funct7
  , input opcode_t opcode
  , input reg_t rs2
  , output ext__b__types::b_alu_control_t b_alu_control
  );

  import ext__b__types::*;

  localparam bit [6:0] FUNCT7_ZBKB__LOGICAL = 7'b0100000;
  localparam bit [6:0] FUNCT7_ZBKB__PACK = 7'b0000100;
  localparam bit [6:0] FUNCT7_ZBKB__ROTATE = 7'b0110000;
  localparam bit [6:0] FUNCT7_ZBKB__BREV8 = 7'b0110100;
  localparam bit [6:0] FUNCT7_ZBKB__ZIP_UNZIP = 7'b0000100;

  always_comb
    case (opcode)
      7'b0110011:
        case (funct7)
          FUNCT7_ZBKB__LOGICAL:
            case (funct3)
              3'b111:  b_alu_control = B_ALU_CTRL__ANDN;
              3'b110:  b_alu_control = B_ALU_CTRL__ORN;
              3'b100:  b_alu_control = B_ALU_CTRL__XNOR;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBKB__PACK:
            case (funct3)
              3'b100:  b_alu_control = B_ALU_CTRL__PACK;
              3'b111:  b_alu_control = B_ALU_CTRL__PACKH;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBKB__ROTATE:
            case (funct3)
              3'b001:  b_alu_control = B_ALU_CTRL__ROL;
              3'b101:  b_alu_control = B_ALU_CTRL__ROR;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          default: b_alu_control = B_ALU_CTRL__NONE;
        endcase
      7'b0010011:
        case (funct7)
          FUNCT7_ZBKB__ROTATE:
            case (funct3)
              3'b101:  b_alu_control = B_ALU_CTRL__RORI;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBKB__BREV8:
            case (funct3)
              3'b101:
                case (rs2)
                  5'b11000: b_alu_control = B_ALU_CTRL__REV8;
                  5'b00111: b_alu_control = B_ALU_CTRL__BREV8;
                  default:  b_alu_control = B_ALU_CTRL__NONE;
                endcase
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBKB__ZIP_UNZIP:
            case (funct3)
              3'b001:
                case (rs2)
                  5'b01111: b_alu_control = B_ALU_CTRL__ZIP;
                  default:  b_alu_control = B_ALU_CTRL__NONE;
                endcase
              3'b101:
                case (rs2)
                  5'b01111: b_alu_control = B_ALU_CTRL__UNZIP;
                  default:  b_alu_control = B_ALU_CTRL__NONE;
                endcase
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          default: b_alu_control = B_ALU_CTRL__NONE;
        endcase
      default: b_alu_control = B_ALU_CTRL__NONE;
    endcase

endmodule
