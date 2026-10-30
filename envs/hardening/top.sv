`include "src/headers/types.svh"
`include "src/interfaces/mem_bus.svh"

module top
  #( parameter MEM_SIZE = 128
  , parameter addr_t BOOT_ADDR = addr_t'(0)
  )
  ( input  wire        clk
  , input  wire        reset
  , output wire [31:0] gpio_out
  );

  mem_bus i_bus();
  mem_bus d_bus();

  wire unused = &{i_bus.write_data, i_bus.write_enable};

  memory_map
    #( .SIZE      ( MEM_SIZE  )
    , .BOOT_ADDR ( BOOT_ADDR )
    )
    u_memory_map
      ( .clk      ( clk       )
      , .reset    ( reset     )
      , .gpio_out ( gpio_out  )

      , .d_bus    ( d_bus.memory )
      , .i_bus    ( i_bus.memory )
      );

  utoss_riscv
    #( .BOOT_ADDR ( BOOT_ADDR ) )
    core
    ( .clk   ( clk            )
    , .reset ( reset          )

    , .d_bus ( d_bus.consumer )
    , .i_bus ( i_bus.consumer )
    );

endmodule
