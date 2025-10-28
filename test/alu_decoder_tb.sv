`timescale 1ns / 1ps

`include "test/utils.svh"

module alu_decoder_tb;

    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [1:0] alu_op;
    logic [3:0] alu_control;

    ALUdecoder ALU_decoder (
        .funct3(funct3),
        .funct7(funct7),
        .alu_op(alu_op),
        .alu_control(alu_control)
    );

  initial begin

    // Test lw/sw (ADD operation)
    alu_op = 2'b00; funct3 = 3'b000; funct7 = 7'b0000000;
    #10;
    assert(alu_control  == 4'b0000) else $fatal(1,"Unexpected zero output for funct3=%b", funct3);

    // Test branch (SUB operation)
    alu_op = 2'b01; funct3 = 3'b000; funct7 = 7'b0000000;
    #10;
    assert(alu_control  == 4'b0001) else $fatal(1,"Unexpected zero output for funct3=%b", funct3);
  /*
      BRANCHIFEQ: begin

        ALUSrcA <= 2'b10;
        ALUSrcB <= 2'b00;
        ALUOp <= 2'b01;
        ResultSrc <= 2'b00;
        Branch <= 1'b1;

      end
  */

    // Test R-type ADD
    alu_op = 2'b10; funct3 = 3'b000; funct7 = 7'b0000000;
    #10;
    assert(alu_control  == 4'b0000) else $fatal(1,"Unexpected zero output for funct3=%b", funct3);

     // Test R-type SUB
    alu_op = 2'b10; funct3 = 3'b000; funct7 = 7'b0100000;
    #10;
    assert(alu_control  == 4'b0001) else $fatal(1,"Unexpected zero output for funct3=%b", funct3);

    // Test R-type XOR
    alu_op = 2'b10; funct3 = 3'b100; funct7 = 7'b0000000;
    #10;
    assert(alu_control  == 4'b0101) else $fatal(1,"Unexpected zero output for funct3=%b", funct3);

    // Test I-type ADDI
    alu_op = 2'b11; funct3 = 3'b000; funct7 = 7'b0000000;
    #10;
    assert(alu_control  == 4'b0000) else $fatal(1,"Unexpected zero output for funct3=%b", funct3);

        // Test I-type ORI
    alu_op = 2'b11; funct3 = 3'b110; funct7 = 7'b0000000;
    #10;
    assert(alu_control  == 4'b1000) else $fatal(1,"Unexpected zero output for funct3=%b", funct3);

    // Test I-type SRAI (funct7 is upper 7 bits of immediate)
    alu_op = 2'b11; funct3 = 3'b101; funct7 = 7'b0100000;
    #10;
    assert(alu_control  == 4'b0111) else $fatal(1,"Unexpected zero output for funct3=%b", funct3);


  end

  `SETUP_VCD_DUMP(alu_decoder_tb)

endmodule
