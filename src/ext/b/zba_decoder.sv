`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

/* verilator lint_off DECLFILENAME */
module ext__b__zba_decoder
/* verilator lint_on DECLFILENAME */
  ( input [2:0] funct3
  , input [6:0] funct7
  , input opcode_t opcode
  , output ext__b__types::b_alu_control_t b_alu_control
  );

  import ext__b__types::*;

  localparam bit [6:0] FUNCT7_ZBA = 7'b0010000;

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
          default: b_alu_control = B_ALU_CTRL__NONE;
        endcase
      default: b_alu_control = B_ALU_CTRL__NONE;
    endcase

endmodule
