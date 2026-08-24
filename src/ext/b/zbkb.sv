`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

module zbkb(
    input [`PROCESSOR_BITNESS - 1:0] rs1
  , input [`PROCESSOR_BITNESS - 1:0] rs2
  , input ext__b__types::b_alu_control_t b_alu_control
  , output reg [`PROCESSOR_BITNESS - 1:0] rd
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

  function automatic logic [XLEN - 1:0] get_pack(input [XLEN - 1:0] rs1, input [XLEN - 1:0] rs2);
    get_pack = {rs2[XLEN / 2 - 1:0], rs1[XLEN / 2 - 1:0]};
  endfunction

  function automatic logic [XLEN - 1:0] get_packh(input [XLEN - 1:0] rs1, input [XLEN - 1:0] rs2);
    get_packh = {{(XLEN - 16){1'b0}}, rs2[7:0], rs1[7:0]};
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
      B_ALU_CTRL__ROL: rd = get_rol(rs1, rs2[SHIFT_WIDTH - 1:0]); // rol (rotate left)
      B_ALU_CTRL__ROR: rd = get_ror(rs1, rs2[SHIFT_WIDTH - 1:0]); // ror (rotate right)
      B_ALU_CTRL__RORI: rd = get_ror(rs1, rs2[SHIFT_WIDTH - 1:0]); // rori (rotate right immediate)
      B_ALU_CTRL__ANDN: rd = rs1 & ~rs2; // andn
      B_ALU_CTRL__ORN: rd = rs1 | ~rs2; // orn
      B_ALU_CTRL__XNOR: rd = ~(rs1 ^ rs2); // xnor
      B_ALU_CTRL__PACK: rd = get_pack(rs1, rs2); // pack
      B_ALU_CTRL__PACKH: rd = get_packh(rs1, rs2); // packh
      B_ALU_CTRL__BREV8: rd = get_brev8(rs1); // brev8
      B_ALU_CTRL__REV8: rd = get_rev8(rs1); // rev8 (byte-reverse)
      default: rd = '0; //other
    endcase

  assign zeroE = (rd == 0);

endmodule