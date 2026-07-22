`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

module zbs
  ( input  data_t                         reg1
  , input  logic [4:0]                    reg2
  , input  ext__b__types::b_alu_control_t  b_alu_control
  , output data_t                         out
);

  import ext__b__types::*;

  always_comb
    case (b_alu_control)
      B_ALU_CTRL__BCLR: out = reg1 & ~(data_t'(32'h1) << reg2);
      B_ALU_CTRL__BSET: out = reg1 | (data_t'(32'h1) << reg2);
      B_ALU_CTRL__BINV: out = reg1 ^ (data_t'(32'h1) << reg2);
      B_ALU_CTRL__BEXT: out = (reg1 >> reg2) & data_t'(32'h1);
      default:          out = '0;
    endcase

endmodule
