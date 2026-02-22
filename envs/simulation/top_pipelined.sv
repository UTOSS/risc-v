`include "src/headers/types.svh"

module top
  #( parameter MEM_SIZE = 1024 )
  ( input wire clk
  , input wire reset
  );

  addr_t       memory__address;
  data_t       memory__write_data;
  logic  [3:0] memory__write_enable;
  data_t       memory__read_data;

  addr_t       imem__address;
  data_t       imem__data;

  MA #( .SIZE ( MEM_SIZE ) )
    memory
      ( .clk          ( clk                  )
      , .address      ( memory__address      )
      , .write_data   ( memory__write_data   )
      , .write_enable ( memory__write_enable )
      , .read_data    ( memory__read_data    )
      );

  MA #( .SIZE ( MEM_SIZE ) )
    imem
      ( .clk          ( clk           )
      , .address      ( imem__address )
      , .write_data   ( 32'hxxxx_xxxx )
      , .write_enable ( 4'b0000       )
      , .read_data    ( imem__data    )
      );

  utoss_riscv_pipelined core
    ( .clk    ( clk    )
    , .reset  ( reset  )

    , .memory_data__address      ( memory__address      )
    , .memory_data__write_data   ( memory__write_data   )
    , .memory_data__write_enable ( memory__write_enable )
    , .memory_data__read_data    ( memory__read_data    )

    , .memory_instr__address      ( imem__address        )
    , .memory_instr__read_data    ( imem__data           )
    );

endmodule
