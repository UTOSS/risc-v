`include "src/timescale.svh"
`include "src/headers/types.svh"

module top_tb;

  logic clk;
  reg rst_n;
  wire [3:0] led;
  wire [7:0] gpio;

  top uut
    ( .clk   ( clk   )
    , .rst_n ( rst_n )
    , .led   ( led   )
    , .gpio  ( gpio  )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    integer i;

    rst_n <= 1'b0;

    for (i = 0; i < 32; i = i + 1) begin
      uut.core.u_decode_stage.RegFile.RFMem[i] = 32'h0;
    end

    #100;

    rst_n <= 1'b1;

    #1000;

    assert (led !== 4'b0) else $fatal(1, "Top TB failed: led stayed 0");
    assert (gpio !== 8'b0) else $fatal(1, "Top TB failed: gpio stayed 0");

    $finish;
  end

  initial begin
    $dumpfile("top_tb.vcd");
    $dumpvars(0, top_tb);
  end
endmodule
