module top
  ( input  wire       CLOCK_50
  , input  wire [3:0] KEY
  , output wire [9:0] LEDR
  );

  addr_t memory__address;
  data_t memory__write_data;
  logic  memory__write_enable;
  data_t memory__read_data;

  MA #( .SIZE ( 8192 ) )
    memory
      ( .clk          ( clk                  )
      , .address      ( memory__address      )
      , .write_data   ( memory__write_data   )
      , .write_enable ( memory__write_enable )
      , .read_data    ( memory__read_data    )
      );

  utoss_riscv core
    ( .clk   ( CLOCK_50 )
    , .reset ( KEY[0]   )
    );

endmodule
