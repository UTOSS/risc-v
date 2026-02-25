`include "src/types.svh"

module BALUdecoder( input[2:0] funct3
                  , input[6:0] funct7
                  , input[6:0] opcode
                  , input[4:0] rd
                  , output reg [3:0] b_alu_control
);

always @(*)

begin
  b_alu_control = 4'b0000; // default to 0 for non-zba/b instructions
  case (alu_op)
    6'b011011:
    begin
      case (funct7)
        7'b0000100: // zba module
        begin
          case (funct3)
            3'b010: b_alu_control = 4'b0001; // sh1add
            3'b100: b_alu_control = 4'b0010; // sh2add
            3'b110: b_alu_control = 4'b0011; // sh3add
          endcase
        end
        7'b0100000: // zbb module
        begin
          case (funct3)
            3'b111: b_alu_control = 4'b0100; // andn
            3'b110: b_alu_control = 4'b0101; // orn
            3'b100: b_alu_control = 4'b0110; // xnor
          endcase
        end

        // TODO: Implement zbs into ALU decoder, also confirm what zbb instructions are being implemented.

      endcase
    end
  endcase
end
endmodule