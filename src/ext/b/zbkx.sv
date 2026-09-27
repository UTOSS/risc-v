`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

module zbkb(
    input [`PROCESSOR_BITNESS - 1:0] a
  , input [`PROCESSOR_BITNESS - 1:0] b
  , input ext__b__types::b_alu_control_t b_alu_control
  , output reg [`PROCESSOR_BITNESS - 1:0] out
  , output wire zeroE
  );

  import ext__b__types::*;

  localparam int XLEN = `PROCESSOR_BITNESS;
  localparam int SHIFT_WIDTH = $clog2(XLEN);

  function automatic logic [3:0] xperm4_lookup (input [3:0] idx , input [XLEN - 1:0] lut);
    xperm4_lookup = lut[idx * 4 +: 4];
  endfunction

  function automatic logic [XLEN - 1:0] get_xperm4 (input [XLEN - 1:0] rs1, input [XLEN - 1:0] rs2);
    for (int i = 0; i < XLEN; i = i + 4) begin
      get_xperm4[i +: 4] = xperm4_lookup(rs2[i +: 4], rs1);
    end
  endfunction

  function automatic logic [7:0] xperm8_lookup (input [7:0] idx , input [XLEN - 1:0] lut);
    xperm8_lookup = lut[idx * 8 +: 8];
  endfunction

  function automatic logic [XLEN - 1:0] get_xperm8 (input [XLEN - 1:0] rs1, input [XLEN - 1:0] rs2);
    for (int i = 0; i < XLEN; i = i + 8) begin
      get_xperm8[i +: 8] = xperm8_lookup(rs2[i +: 8], rs1);
    end
  endfunction

  always_comb
    case (b_alu_control)
      B_ALU_CTRL__XPERM4: out = get_xperm4(a, b); // XPERM4 (Nibble-wise lookup of indices into a vector)
      B_ALU_CTRL__XPERM8: out = get_xperm8(a, b); // XPERM8 (Byte-wise lookup of indices into a vector in registers)
      default: out = '0; // other
    endcase

  assign zeroE = (out == 0);

endmodule
