`timescale 1ns/1ps

module alu_dut;
  logic [31:0] a;
  logic [31:0] b;
  logic [3:0] alu_control;
  logic [31:0] out;
  logic zeroE;
  

  ALU dut (
    .a(a),
    .b(b),
    .alu_control(alu_control),
    .out(out),
    .zeroE(zeroE)
  );
endmodule
