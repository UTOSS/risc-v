`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"
/* verilator lint_off DECLFILENAME */
module ext__b__decoder
/* verilator lint_on DECLFILENAME */
  ( input [2:0] funct3
  , input [6:0] funct7
  , input opcode_t opcode
  /* verilator lint_off UNUSEDSIGNAL */
  , input reg_t rd
  /* verilator lint_on UNUSEDSIGNAL */
  , input reg_t rs2
  , output ext__b__types::b_alu_control_t b_alu_control
  );

  import ext__b__types::*;

  localparam bit [6:0] FUNCT7_ZBA = 7'b0010000;
  localparam bit [6:0] FUNCT7_ZBB__LOGICAL = 7'b0100000;
  localparam bit [6:0] FUNCT7_ZBB__MINMAX = 7'b0000101;
  localparam bit [6:0] FUNCT7_PACK_GROUP = 7'b0000100;
  localparam bit [6:0] FUNCT7_ZBB__ROTATE = 7'b0110000;
  localparam bit [6:0] FUNCT7_ZBB__ORCB  = 7'b0010100;
  localparam bit [6:0] FUNCT7_ZBB__REV8_BREV8  = 7'b0110100;
  localparam bit [6:0] FUNCT7_ZBKB__ZIP_UNZIP  = 7'b0000100;

  always_comb
    case (opcode)
      7'b0110011:
        case (funct7)
          FUNCT7_ZBA:
            case (funct3)
              3'b010:  b_alu_control = B_ALU_CTRL__SH1ADD;
              3'b100:  b_alu_control = B_ALU_CTRL__SH2ADD;
              3'b110:  b_alu_control = B_ALU_CTRL__SH3ADD;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBB__LOGICAL:
            case (funct3)
              3'b111:  b_alu_control = B_ALU_CTRL__ANDN;
              3'b110:  b_alu_control = B_ALU_CTRL__ORN;
              3'b100:  b_alu_control = B_ALU_CTRL__XNOR;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBB__MINMAX:
            case (funct3)
              3'b100:  b_alu_control = B_ALU_CTRL__MIN;
              3'b101:  b_alu_control = B_ALU_CTRL__MINU;
              3'b110:  b_alu_control = B_ALU_CTRL__MAX;
              3'b111:  b_alu_control = B_ALU_CTRL__MAXU;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBB__ROTATE:
            case (funct3)
              3'b001:  b_alu_control = B_ALU_CTRL__ROL;
              3'b101:  b_alu_control = B_ALU_CTRL__ROR;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_PACK_GROUP:
            case (funct3)
              3'b100:
                case (rs2)
                  5'b00000: b_alu_control = B_ALU_CTRL__ZEXTH;
                  default: b_alu_control = B_ALU_CTRL__PACK;
                endcase
              3'b111: b_alu_control = B_ALU_CTRL__PACKH;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          // TODO: Implement zbs into ALU decoder, also confirm what zbb instructions are being implemented.
          default: b_alu_control = B_ALU_CTRL__NONE;
        endcase

      7'b0010011:
        case (funct7)
          FUNCT7_ZBB__ROTATE:
            case (funct3)
              3'b001:
                case (rs2)
                  5'b00100:  b_alu_control = B_ALU_CTRL__SEXTB;
                  5'b00101:  b_alu_control = B_ALU_CTRL__SEXTH;
                  5'b00000:  b_alu_control = B_ALU_CTRL__CLZ;
                  5'b00001:  b_alu_control = B_ALU_CTRL__CTZ;
                  5'b00010:  b_alu_control = B_ALU_CTRL__CPOP;
                  default:   b_alu_control = B_ALU_CTRL__NONE;
                endcase
              3'b101: b_alu_control = B_ALU_CTRL__RORI;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBB__ORCB:
            case (funct3)
              3'b101:
                case (rs2)
                  5'b00111: b_alu_control = B_ALU_CTRL__ORCB;
                  default:  b_alu_control = B_ALU_CTRL__NONE;
                endcase
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase
          FUNCT7_ZBB__REV8_BREV8:
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
              default:  b_alu_control = B_ALU_CTRL__NONE;
            endcase
          default:  b_alu_control = B_ALU_CTRL__NONE;
        endcase
      default:  b_alu_control = B_ALU_CTRL__NONE;
    endcase

endmodule
