`timescale 1ns/1ps

module top_tb;

  logic clk;
  logic [3:0] reset;
  logic [9:0] ledr;

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
    reset <= 4'b1111; #10; reset <= 4'b0000;

    #1000;

    assert (ledr === 10'b1000000) else $fatal(1, "Top TB failed");
  end

  initial begin
    $dumpfile("top_tb.vcd");
    $dumpvars(0, top_tb);
  end
endmodule
