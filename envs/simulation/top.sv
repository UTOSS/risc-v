`include "src/headers/types.svh"
`include "src/interfaces/MEM_BUS.svh"

module top
  #( parameter MEM_SIZE = 1024 ) //maybe change to 2048 if using dual port?
  ( input wire clk
  , input wire reset
  );

  MEM_BUS i_bus();
  MEM_BUS d_bus();

  wire unused = &{i_bus.memory__write_data, i_bus.memory__write_enable};
  memory #( .SIZE ( MEM_SIZE ) )
  // u could prob do the same from the core thingy here @Bugget
    u_memory
      ( .clk                      ( clk                  )
      , .d_bus(d_bus)
      , .i_bus(i_bus)
      );

  utoss_riscv core
    ( .clk    ( clk    )
    , .reset  ( reset  )
    , .d_bus(d_bus)
    , .i_bus(i_bus)
    );

endmodule
