`include "src/types.svh"

module BALUdecoder
  ( input [2:0] funct3
  , input [6:0] funct7
  , input [6:0] opcode
  , input [4:0] rd
  , output b_alu_control_t b_alu_control
  );

always @(*)

begin
  b_alu_control = B_ALU_CTRL__NONE; // default to NONE for non-zba/b instructions
  case (opcode)
    6'b011011:
    begin
      case (funct7)
        7'b0000100: // zba module
        begin
          case (funct3)
            3'b010: b_alu_control = B_ALU_CTRL__SH1ADD;
            3'b100: b_alu_control = B_ALU_CTRL__SH2ADD;
            3'b110: b_alu_control = B_ALU_CTRL__SH3ADD;
          endcase
        end
        7'b0100000: // zbb module
        begin
          case (funct3)
            3'b111: b_alu_control = B_ALU_CTRL__ANDN;
            3'b110: b_alu_control = B_ALU_CTRL__ORN;
            3'b100: b_alu_control = B_ALU_CTRL__XNOR;
          endcase
        end

        // TODO: Implement zbs into ALU decoder, also confirm what zbb instructions are being implemented.

      endcase
    end
  endcase
end
endmodule
