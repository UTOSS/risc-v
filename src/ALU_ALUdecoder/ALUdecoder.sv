`include "src/types.svh"
`timescale 1ns/1ps


module ALUdecoder ( input [2:0] funct3
                  , input [6:0] funct7
                  , input alu_op_t alu_op
                  , output reg [3:0] alu_control
                  );
  always @(*)
  begin
    alu_control = 4'b0000;
  case (alu_op)
    ALU_OP__ADD: alu_control = 4'b0000; //lw, sw (ADD)
    ALU_OP__BRANCH:
    begin
      case (funct3)
      3'b000: alu_control = 4'b0001; //beq (SUB)
      3'b001: alu_control = 4'b0001; // bne (SUB)
      3'b100: alu_control = 4'b0011; // blt (SLT)
      3'b110: alu_control = 4'b0100; // bltu (SLTU)
      3'b101: alu_control = 4'b1010; // bge (SGE)
      3'b111: alu_control = 4'b1011; // bgeu (SGEU)
      default: alu_control = 4'b0001; // SUB
      endcase
    end
    ALU_OP__REGISTER_OPERATION: //R type
    begin
      case (funct3)
      3'b000: if (funct7 == 7'h00) alu_control = 4'b0000;      //ADD
        else if (funct7 == 7'h20) alu_control = 4'b0001; //SUB
        else alu_control = 4'b0000; // default to ADD for invalid func7
      3'b001: alu_control = 4'b0010;                         //SLL
      3'b010: alu_control = 4'b0011;                         //SLT
      3'b011: alu_control = 4'b0100;                         //SLTU
      3'b100: alu_control = 4'b0101;              //XOR
      3'b101: if (funct7 == 7'h00) alu_control = 4'b0110;      //SRL
        else if (funct7 == 7'h20) alu_control = 4'b0111; //SRA
        else alu_control = 4'b0110; // default to SRL for invalid func7
      3'b110: alu_control = 4'b1000;                         //OR
      3'b111: alu_control = 4'b1001;                         //AND
      default: alu_control = 4'b0000;
      endcase
    end
    ALU_OP__UNSET: //I type
    begin
      case (funct3)
      3'b000: alu_control = 4'b0000;                //ADDI
      3'b001: alu_control = 4'b0010;                         //SLLI
      3'b010: alu_control = 4'b0011;                         //SLTI
      3'b011: alu_control = 4'b0100;                         //SLTIU
      3'b100: alu_control = 4'b0101;              //XORI
      3'b101: if (funct7 == 7'h00) alu_control = 4'b0110;      //SRLI
        else if (funct7 == 7'h20) alu_control = 4'b0111;    //SRAI
        else alu_control = 4'b0110; // default to SRLI for invalid func7
// I type doesn't have funct7; the funct7 here is the upper 7 bits of the immediate
      3'b110: alu_control = 4'b1000;                         //ORI
      3'b111: alu_control = 4'b1001;                         //ANDI
      default: alu_control = 4'b0000;
      endcase
    end
    default: alu_control = 4'b0000;
  endcase
  end
endmodule
