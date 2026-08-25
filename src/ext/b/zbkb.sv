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

  function automatic logic [XLEN - 1:0] get_rol(input logic [XLEN - 1:0] val, input logic[SHIFT_WIDTH - 1:0] shift_amount);
    if (shift_amount == 0) begin
      get_rol = val;
    end
    else begin
      get_rol = val << shift_amount;
      get_rol |= val >> (XLEN - XLEN'(shift_amount));
    end
  endfunction

  function automatic logic [XLEN - 1:0] get_ror(input logic [XLEN - 1:0] val, input logic[SHIFT_WIDTH - 1:0] shift_amount);
    if (shift_amount == 0) begin
      get_ror = val;
    end
    else begin
      get_ror = val >> shift_amount;
      get_ror |= val << (XLEN - XLEN'(shift_amount));
    end
  endfunction

  function automatic logic [XLEN - 1:0] get_pack(input [XLEN - 1:0] a, input [XLEN - 1:0] b);
    get_pack = {b[XLEN / 2 - 1:0], a[XLEN / 2 - 1:0]};
  endfunction

  function automatic logic [XLEN - 1:0] get_packh(input [XLEN - 1:0] a, input [XLEN - 1:0] b);
    get_packh = {{(XLEN - 16){1'b0}}, b[7:0], a[7:0]};
  endfunction

  function automatic logic [XLEN - 1:0] get_brev8(input logic [XLEN - 1:0] val);
    for (int j = 0; j < XLEN / 8; j++) begin
      for (int i=0; i < 8; i ++) begin
        get_brev8[i + j * 8] = val[XLEN - i - (XLEN / 8 - 1 - j) * 8 - 1];
      end
    end
  endfunction

  function automatic logic [XLEN - 1:0] get_rev8(input logic [XLEN - 1:0] val);
    for (int i=0; i < XLEN; i += 8) begin
      get_rev8[i +: 8] = val[(XLEN - 8 - i) +: 8];
    end
  endfunction

  always_comb
    case (b_alu_control)
      B_ALU_CTRL__ROL: out = get_rol(a, b[SHIFT_WIDTH - 1:0]); // rol (rotate left)
      B_ALU_CTRL__ROR: out = get_ror(a, b[SHIFT_WIDTH - 1:0]); // ror (rotate right)
      B_ALU_CTRL__RORI: out = get_ror(a, b[SHIFT_WIDTH - 1:0]); // rori (rotate right immediate)
      B_ALU_CTRL__ANDN: out = a & ~b; // andn
      B_ALU_CTRL__ORN: out = a | ~b; // orn
      B_ALU_CTRL__XNOR: out = ~(a ^ b); // xnor
      B_ALU_CTRL__PACK: out = get_pack(a, b); // pack (pack lower halves)
      B_ALU_CTRL__PACKH: out = get_packh(a, b); // packh (pack lower bytes)
      B_ALU_CTRL__REV8: out = get_rev8(a); // rev8 (byte-reverse)
      B_ALU_CTRL__BREV8: out = get_brev8(a); // brev8 (reverse bits in each byte)
      default: out = '0; // other
    endcase

  assign zeroE = (out == 0);

endmodule
