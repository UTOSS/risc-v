//`include "params.vh"

module ALU ( input [31:0] a
           , input [31:0] b
           , input [3:0] alu_control
           , output reg [31:0] out
           , output zeroE
           );
    always @(*)
  begin
  case (alu_control)
            4'b0000: out = a + b;                    // ADD
            4'b0001: out = a - b;                    // SUB
            4'b0010: out = a << b[4:0];              // SLL
            4'b0011: out = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0; // SLT
            4'b0100: out = (a < b) ? 32'b1 : 32'b0;  // SLTU
            4'b0101: out = a ^ b;                    // XOR
            4'b0110: out = a >> b[4:0];              // SRL
            4'b0111: out = $signed(a) >>> b[4:0];    // SRA
            4'b1000: out = a | b;                    // OR
            4'b1001: out = a & b;                    // AND
            default: out = 32'b0;
  endcase
  end
  assign zeroE = (out == 0);
endmodule

