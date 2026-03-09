`include "types.svh"
module ALU
(
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  alu_op_t_low alu_control,
  output reg [31:0] out,
  output logic zeroE
);

always_comb begin
    case (alu_control)
        ALUAdd:  out = a + b;
        ALUSub:  out = a - b;
        ALUSLL:  out = a << b[4:0];
        ALUSLT:  out = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
        ALUSLTU: out = (a < b) ? 32'b1 : 32'b0;
        ALUXOR:  out = a ^ b;
        ALUSRL:  out = a >> b[4:0];
        ALUSRA:  out = $signed(a) >>> b[4:0];
        ALUOR:   out = a | b;
        ALUAND:  out = a & b;
        default: out = 32'b0;
    endcase
end

assign zeroE = (out == 0);

endmodule