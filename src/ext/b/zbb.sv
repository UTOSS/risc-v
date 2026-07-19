`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

module zbb(
    input [`PROCESSOR_BITNESS - 1:0] a
  , input [`PROCESSOR_BITNESS - 1:0] b
  , input ext__b__types::b_alu_control_t b_alu_control
  , output reg [`PROCESSOR_BITNESS - 1:0] out
  , output wire zeroE
  );

  import ext__b__types::*;

  localparam int XLEN = `PROCESSOR_BITNESS;
  localparam int COUNT_WIDTH = $clog2(XLEN + 1);
  localparam int SHIFT_WIDTH = $clog2(XLEN);

  function automatic logic [COUNT_WIDTH - 1:0] get_clz(input logic [XLEN - 1:0] val);
    get_clz = COUNT_WIDTH'(XLEN);
    for (int i=0; i < XLEN; i++) begin
      if (val[i]) get_clz = COUNT_WIDTH'(XLEN - 1 - i);
    end
  endfunction

  function automatic logic [COUNT_WIDTH - 1:0] get_ctz(input logic [XLEN - 1:0] val);
    get_ctz = COUNT_WIDTH'(XLEN);
    for (int i=0; i < XLEN; i++) begin
      if (val[i]) begin
        get_ctz = COUNT_WIDTH'(i);
        break;
      end
    end
  endfunction

  function automatic logic [COUNT_WIDTH - 1:0] get_cpop(input logic [XLEN - 1:0] val);
    get_cpop = 0;
    for (int i=0; i < XLEN; i++) begin
      if (val[i]) get_cpop = get_cpop + 1'b1;
    end
  endfunction

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

  function automatic logic [XLEN - 1:0] get_orcb(input logic [XLEN - 1:0] val);
    for (int i=0; i < XLEN; i += 8) begin
      if (val[i +: 8] == 0) begin
        get_orcb[i +: 8] = 8'b0;
      end
      else begin
        get_orcb[i +: 8] = 8'b11111111;
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
      B_ALU_CTRL__ANDN: out = a & ~b; //andn
      B_ALU_CTRL__ORN: out = a | ~b; //orn
      B_ALU_CTRL__XNOR: out = ~(a ^ b); //xnor
      B_ALU_CTRL__MIN: out = ($signed(a) < $signed(b) ? a : b); //min
      B_ALU_CTRL__MAX: out = ($signed(a) < $signed(b) ? b : a); //max
      B_ALU_CTRL__MINU: out = (a < b) ? a : b; //minu
      B_ALU_CTRL__MAXU: out = (a < b) ? b : a; //maxu
      B_ALU_CTRL__SEXTB: out = {{(XLEN - 8){a[7]}}, a[7:0]}; //sext.b (sign extend byte)
      B_ALU_CTRL__SEXTH: out = {{(XLEN - 16){a[15]}}, a[15:0]}; //sext.h (sign extend halfword)
      B_ALU_CTRL__ZEXTH: out = {{(XLEN - 16){1'b0}}, a[15:0]}; //zext.h (zero extend halfword)
      B_ALU_CTRL__CLZ: out = {{(XLEN - COUNT_WIDTH){1'b0}}, get_clz(a)}; //clz (count leading zeroes)
      B_ALU_CTRL__CTZ: out = {{(XLEN - COUNT_WIDTH){1'b0}}, get_ctz(a)}; //ctz (count trailing zeroes)
      B_ALU_CTRL__CPOP: out = {{(XLEN - COUNT_WIDTH){1'b0}}, get_cpop(a)}; //cpop (count population)
      B_ALU_CTRL__ROL: out = get_rol(a, b[SHIFT_WIDTH - 1:0]); //rol (rotate left)
      B_ALU_CTRL__ROR: out = get_ror(a, b[SHIFT_WIDTH - 1:0]); //ror (rotate right)
      B_ALU_CTRL__RORI: out = get_ror(a, b[SHIFT_WIDTH - 1:0]); //rori (rotate right immediate)
      B_ALU_CTRL__ORCB: out = get_orcb(a); //orc.b (OR combine bytes)
      B_ALU_CTRL__REV8: out = get_rev8(a); //rev8 (byte-reverse)
      default: out = '0; //other
    endcase

  assign zeroE = (out == 0);

endmodule
