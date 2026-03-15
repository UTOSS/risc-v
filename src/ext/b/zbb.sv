module zbb(
    input [31:0] a
  , input [31:0] b
  , input [2:0] zbb_control
  , output reg [31:0] out
  , output zeroE
  );

  always_comb
    case (zbb_control)
      3'b000: out = a & ~b; //andn
      3'b001: out = a | ~b; //orn
      3'b010: out = ~(a ^ b); //xnor
      3'b011: out = ($signed(a) < $signed(b) ? a : b); //min
      3'b100: out = ($signed(a) < $signed(b) ? b : a); //max
      3'b101: out = { {24{a[7]}}, a[7:0]}; //sext.b (sign extend byte)
      3'b110: out = { {16{a[15]}}, a[15:0]}; //sext.h (sign extend halfword)
      3'b111: out = {16'b0, a[15:0]}; //zext.h (zero extend halfword)
      default: out = 32'd0; //other
    endcase

  assign zeroE = (out == 0);

endmodule