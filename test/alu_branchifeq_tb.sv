`timescale 1ns / 1ps

`include "test/utils.svh"

module alu_branchifeq_tb;

    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [1:0] alu_op;
    logic [3:0] alu_control;
  logic [31:0] A;
  logic [31:0] B;
  logic [31:0] out;

  /* verilator lint_off UNUSEDSIGNAL */
  logic zeroE;
  /* verilator lint_on UNUSEDSIGNAL */

    ALUdecoder ALU_decoder
      ( .funct3(funct3)
      , .funct7(funct7)
      , .alu_op(alu_op)
      , .alu_control(alu_control)
      );

  ALU alu (.a(A), .b(B), .alu_control(alu_control), .out(out), .zeroE(zeroE));

  initial begin
  // Test decode
  //set old PC = 0x0; (A=0) set branching is to add 16 (B = 16);
  alu_op = 2'b00; funct3 = 3'bxxx; funct7 = 7'bxxxxxxx;
  A = 32'h0; B = 32'h10;
  /*      DECODE: begin

        ALUSrcA <= 2'b01;
        ALUSrcB <= 2'b01;
        ALUOp <= 2'b00;

      end
  */

    // Test branch (SUB operation)
    alu_op = 2'b01; funct3 = 3'b000; funct7 = 7'b0000000;
  A = 32'h0010; B = 32'h0010;
    #10;
    assert (alu_control == 4'b0001) else $fatal(1, "Unexpected zero output for funct3=%b", funct3);
  assert (out == 32'b0) else $fatal(1, "not branching when equal for funct3=%b", funct3);
  $display("finish testing");
  /*
      BRANCHIFEQ: begin

        ALUSrcA <= 2'b10;
        ALUSrcB <= 2'b00;
        ALUOp <= 2'b01;
        ResultSrc <= 2'b00;
        Branch <= 1'b1;

      end
  */
  end

  `SETUP_VCD_DUMP(alu_branchifeq_tb)

endmodule
