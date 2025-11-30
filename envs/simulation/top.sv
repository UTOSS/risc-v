`include "src/types.svh"

module top
  #( parameter MEM_SIZE = 1024 )
  ( input wire clk
  , input wire reset
  );

  addr_t       memory__address;
  data_t       memory__write_data;
  logic  [3:0] memory__write_enable;
  data_t       memory__read_data;

  MA #( .SIZE ( MEM_SIZE ) )
    memory
      ( .clk          ( clk                  )
      , .address      ( memory__address      )
      , .write_data   ( memory__write_data   )
      , .write_enable ( memory__write_enable )
      , .read_data    ( memory__read_data    )
      );

  utoss_riscv core
    ( .clk    ( clk    )
    , .reset  ( reset  )

    , .memory__address      ( memory__address      )
    , .memory__write_data   ( memory__write_data   )
    , .memory__write_enable ( memory__write_enable )
    , .memory__read_data    ( memory__read_data    )
    );

endmodule
