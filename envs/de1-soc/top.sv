module top
  ( input  wire       CLOCK_50
  , input  wire [3:0] KEY
  , output wire [9:0] LEDR
  );

  addr_t       memory_data__address;
  data_t       memory_data__write;
  logic  [3:0] memory_data__write_enable;
  data_t       memory_data__read;

  addr_t       memory_instr__address;
  data_t       memory_instr__write;
  logic  [3:0] memory_instr__write_enable;
  data_t       memory_instr__read;

  memory_map #( .SIZE ( 512 ) )
    memory_map
      ( .clk ( CLOCK_50 )

      , .data__address      ( memory_data__address      )
      , .data__write        ( memory_data__write        )
      , .data__write_enable ( memory_data__write_enable )
      , .data__read         ( memory_data__read         )

      , .instr__address     ( memory_instr__address     )
      , .instr__read        ( memory_instr__read        )

      , .LEDR ( LEDR )
      );

  utoss_riscv core
    ( .clk   ( CLOCK_50 )
    , .reset ( ~KEY[0]   )

    , .memory_data__address      ( memory_data__address      )
    , .memory_data__write_data   ( memory_data__write        )
    , .memory_data__write_enable ( memory_data__write_enable )
    , .memory_data__read_data    ( memory_data__read         )

    , .memory_instr__address      ( memory_instr__address      )
    , .memory_instr__write_data   ( memory_instr__write        )
    , .memory_instr__write_enable ( memory_instr__write_enable )
    , .memory_instr__read_data    ( memory_instr__read         )
    );

endmodule
