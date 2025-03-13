// dummy extend module

`include "src/types.svh"

module extend ( input  wire [11:0] in
              , output imm_t       imm_ext
              );
  assign imm_ext = {{20{in[11]}}, in};
endmodule
