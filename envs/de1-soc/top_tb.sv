`timescale 1ns/1ps

module top_tb;

  logic clk;
  reg [3:0] reset;
  reg [9:0] ledr;

  top uut
    ( .CLOCK_50 ( clk   )
    , .KEY      ( reset )
    , .LEDR     ( ledr  )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    integer i;

    reset <= 4'b0000;

    for (i = 0; i < 32; i = i + 1) begin
      uut.core.RegFile.RFMem[i] = 32'h0;
    end

    #100;

    reset <= 4'b1111;

    #1000;

    assert (ledr !== 10'b0) else $fatal(1, "Top TB failed");

    $finish;
  end

  initial begin
    $dumpfile("top_tb.vcd");
    $dumpvars(0, top_tb);
  end
endmodule
