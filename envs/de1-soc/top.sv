module top
  ( input  wire       CLOCK_50
  , input  wire [3:0] KEY
  , output wire [9:0] LEDR
  );

  // Clock division: 50MHz to 5MHz (divide by 10)
  reg [3:0] clk_counter = 0;
  reg clk_5mhz = 0;

  always @(posedge CLOCK_50) begin
    if (clk_counter == 4'd9) begin
      clk_counter <= 0;
      clk_5mhz <= ~clk_5mhz;
    end else begin
      clk_counter <= clk_counter + 1;
    end
  end

  addr_t       memory__address;
  data_t       memory__write_data;
  logic  [3:0] memory__write_enable;
  data_t       memory__read_data;

  memory_map #( .SIZE ( 512 ) )
    memory_map
      ( .clk ( clk_5mhz )

      , .address      ( memory__address      )
      , .write_data   ( memory__write_data   )
      , .write_enable ( memory__write_enable )
      , .read_data    ( memory__read_data    )

      , .LEDR ( LEDR )
      );

  utoss_riscv core
    ( .clk   ( clk_5mhz )
    , .reset ( KEY[0]   )

    , .memory__address      ( memory__address      )
    , .memory__write_data   ( memory__write_data   )
    , .memory__write_enable ( memory__write_enable )
    , .memory__read_data    ( memory__read_data    )
    );

endmodule
