`include "src/interfaces/mem_bus.svh"

module top
  ( input  wire       CLOCK_50
  , input  wire [3:0] KEY
  , output wire [9:0] LEDR
  );

  mem_bus i_bus();
  mem_bus d_bus();

  memory_map #( .SIZE ( 512 ) )
    memory_map
      ( .clk ( CLOCK_50 )
      , .LEDR ( LEDR )

      , .d_bus ( d_bus )
      , .i_bus ( i_bus )
      );

  utoss_riscv core
    ( .clk   ( CLOCK_50 )
    , .reset ( ~KEY[0]  )

    , .d_bus ( d_bus )
    , .i_bus ( i_bus )
    );

endmodule
