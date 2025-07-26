`timescale 1ns/1ps

`include "src/top.v"

module dut;

  reg clk;
  reg reset;

  top #( .MEM_SIZE ( 250000 /* 1MB */ ) )
    top
      ( .clk   ( clk   )
      , .reset ( reset )
      );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  inital begin
    reset <= `TRUE;
    @(posedge clk); #1
    reset <= `FALSE;
  end

endmodule
