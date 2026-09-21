`include "src/timescale.svh"

// sh1add - logical shift left by 1 and add
// sh2add - logical shift left by 2 and add
// sh3add - logical shift left by 3 and add

// Logic shift: Moves bits N positions to the left leaving 0's behind
// x << n = x * 2^n

module zba(input [31:0] reg1
  , input [31:0] reg2
  , input [2:0] inst // two bit register, distinguish instruction
  /* verilator lint_off UNUSEDSIGNAL */
  , output logic[31:0] out
  );

always_comb

    case (inst)

// sh1add behaviour

    3'b010: out = (reg1 << 1) + reg2;

// sh2add behaviour

    3'b100: out = (reg1 << 2) + reg2;

// sh3add

    3'b110: out = (reg1 << 3) + reg2;

// other

    default: out = 32'd0;

    endcase

endmodule
