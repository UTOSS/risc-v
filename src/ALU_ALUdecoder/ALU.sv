`include "src/types.svh"
module ALU
(
  input logic [31:0] a
  , input logic [31:0] b
  , input alu_control_t alu_control
  , output reg [31:0] out
  , output logic zeroE
);

always_comb
    case (alu_control)
        ALU_CONTROL_ADD:  out = a + b;
        ALU_CONTROL_SUB:  out = a - b;
        ALU_CONTROL_SLL:  out = a << b[4:0];
        ALU_CONTROL_SLT:  out = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
        ALU_CONTROL_SLTU: out = (a < b) ? 32'b1 : 32'b0;
        ALU_CONTROL_XOR:  out = a ^ b;
        ALU_CONTROL_SRL:  out = a >> b[4:0];
        ALU_CONTROL_SRA:  out = $signed(a) >>> b[4:0];
        ALU_CONTROL_OR:   out = a | b;
        ALU_CONTROL_AND:  out = a & b;
        default: out = 32'b0;
    endcase

assign zeroE = (out == 0);

endmodule