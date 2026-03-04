`include "src/headers/types.svh"

module dual_port
  #( parameter SIZE = 2048 )
  ( input  wire         clk
  , input  addr_t       address
  , input  addr_t       instruction_address
  , input  data_t       write_data
  , input  wire   [3:0] write_enable
  , output data_t       read_data
  , output data_t       instruction_read_data
  );

  MA #( .SIZE ( SIZE ) )
    memory
      ( .clk          ( clk                  )
      , .address      ( address      )
      , .write_data   ( write_data   )
      , .write_enable ( write_enable )
      , .read_data    ( read_data    )
      );

MA #( .SIZE ( SIZE ) )
  imem
    ( .clk          ( clk           )
    , .address      ( instruction_address )
    , .write_data   ( 32'hxxxx_xxxx )
    , .write_enable ( 4'b0000       )
    , .read_data    ( instruction_read_data    )
    );
endmodule