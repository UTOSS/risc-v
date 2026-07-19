`include "src/headers/types.svh"

module top
  #( parameter MEM_SIZE = 1024 ) //maybe change to 2048 if using dual port?
  ( input wire clk
  , input wire reset
  );

  addr_t       memory__address;
  data_t       memory__write_data;
  logic  [3:0] memory__write_enable;
  data_t       memory__read_data;

  addr_t       imem__address;
  data_t       imem__read_data;

  data_t       imem__write_data;
  logic [3:0]  imem__write_enable;

  wire unused = &{imem__write_data, imem__write_enable};

  memory #( .SIZE ( MEM_SIZE ) )
    u_memory
      ( .clk                      ( clk                  )
      , .address                  ( memory__address      )
      , .instruction_address      ( imem__address        )
      , .write_data               ( memory__write_data   )
      , .write_enable             ( memory__write_enable )
      , .read_data                ( memory__read_data    )
      , .instruction_read_data    ( imem__read_data      )
      );

  utoss_riscv core
    ( .clk    ( clk    )
    , .reset  ( reset  )

    , .memory_data__address      ( memory__address      )
    , .memory_data__write_data   ( memory__write_data   )
    , .memory_data__write_enable ( memory__write_enable )
    , .memory_data__read_data    ( memory__read_data    )

    , .memory_instr__address      ( imem__address        )
    , .memory_instr__write_data   ( imem__write_data     )
    , .memory_instr__write_enable ( imem__write_enable   )
    , .memory_instr__read_data    ( imem__read_data      )
    );

endmodule
