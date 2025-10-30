module top
  ( input  wire       CLOCK_50
  , input  wire [3:0] KEY
  , output wire [9:0] LEDR
  );

  utoss_riscv core
    ( .clk   ( CLOCK_50 )
    , .reset ( KEY[0]   )
    );

endmodule
