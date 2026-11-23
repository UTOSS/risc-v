`include "src/interfaces/mem_bus.svh"

module top
  ( input  wire       clk
  , input  wire       rst_n
  , output wire [3:0] led
  , output wire [7:0] gpio
  );

  mem_bus i_bus();
  mem_bus d_bus();

  memory_map #( .SIZE ( 512 ) )
    memory_map
      ( .clk   ( clk   )
      , .led   ( led   )
      , .gpio  ( gpio  )
      , .d_bus ( d_bus )
      , .i_bus ( i_bus )
      );

  utoss_riscv core
    ( .clk   ( clk    )
    , .reset ( ~rst_n )
    , .d_bus ( d_bus  )
    , .i_bus ( i_bus  )
    );

endmodule
