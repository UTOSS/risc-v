`include "src/types.svh"

module BALUdecoder
  ( input [2:0] funct3
  , input [6:0] funct7
  , input [6:0] opcode
  , input [4:0] rd
  , output b_alu_control_t b_alu_control
  );

  localparam bit [6:0] FUNCT7_ZBA = 7'b0010000;
  localparam bit [6:0] FUNCT7_ZBB = 7'b0100000;

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

          FUNCT7_ZBB:
            case (funct3)
              3'b111:  b_alu_control = B_ALU_CTRL__ANDN;
              3'b110:  b_alu_control = B_ALU_CTRL__ORN;
              3'b100:  b_alu_control = B_ALU_CTRL__XNOR;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase

          // TODO: Implement zbs into ALU decoder, also confirm what zbb instructions are being implemented.
          default: b_alu_control = B_ALU_CTRL__NONE;

        endcase

      default: b_alu_control = B_ALU_CTRL__NONE;
    endcase

endmodule
