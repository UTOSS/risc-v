`include "src/headers/types.svh"
`include "src/interfaces/mem_bus.svh"

module top
  #( parameter MEM_SIZE = 1024 ) //maybe change to 2048 if using dual port?
  ( input wire clk
  , input wire reset
  );

  mem_bus i_bus();
  mem_bus d_bus();

  wire unused = &{i_bus.write_data, i_bus.write_enable};
  memory #( .SIZE ( MEM_SIZE ) )
    u_memory
      ( .clk   ( clk   )
      , .d_bus ( d_bus )
      , .i_bus ( i_bus )
      );

  utoss_riscv core
    ( .clk   ( clk   )
    , .reset ( reset )
    , .d_bus ( d_bus )
    , .i_bus ( i_bus )
    );

endmodule
