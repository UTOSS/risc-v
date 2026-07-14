//do i need include?

`include "src/interfaces/MEM_BUS.svh"

module top
  ( input  wire       CLOCK_50
  , input  wire [3:0] KEY
  , output wire [9:0] LEDR
  );

  MEM_BUS i_bus();
  MEM_BUS d_bus();


  // added to mirror memory.sv in envs/simulation
  // wire unused = &{i_bus.memory__write_data, i_bus.memory__write_enable};

  memory_map #( .SIZE ( 512 ) )
    memory_map
      ( .clk ( CLOCK_50 )

      , .d_bus(d_bus)
      , .i_bus(i_bus)

      , .LEDR ( LEDR )
      );

  utoss_riscv core
    ( .clk   ( CLOCK_50 )
    , .reset ( ~KEY[0]   )
    , .d_bus(d_bus)
    , .i_bus(i_bus)
    );

endmodule
