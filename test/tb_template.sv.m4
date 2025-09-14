changequote([,])dnl
`timescale 1ns/1ps

`include "test/utils.svh"

module M4__TB_NAME;

  /* module name here */ uut
    ( .clk ( clk )
    // other inputs/outputs
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    // write tests here
  end

  `SETUP_VCD_DUMP(M4__TB_NAME)

endmodule
