`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

module csr_data
  ( input logic clk
  , input logic reset

  /* verilator lint_off UNUSEDSIGNAL */ // only `address` is needed for the read
  , input  ext__zicsr__types::csr_request_t    csr_request
  /* verilator lint_on UNUSEDSIGNAL */
  , input  ext__zicsr__types::csr_wb_request_t csr_wb_request
  , output data_t                              csr_data
  );

  data_t mscratch_read_value;
  data_t mhartid_read_value;

  csr_plugin
    #( .NAME        ( "mscratch"         )
    , .ADDRESS      ( 12'h340            )
    , .RESET_VALUE  ( 32'h0000_0000      )
    , .WRITE_MASK   ( 32'hffff_ffff      )
    )
    u_mscratch
    ( .clk            ( clk                 )
    , .reset          ( reset               )
    , .read_address   ( csr_request.address )
    , .read_value     ( mscratch_read_value )
    , .csr_wb_request ( csr_wb_request      )
    );

  csr_plugin
    #( .NAME        ( "mhartid"         )
    , .ADDRESS      ( 12'hf14           )
    , .RESET_VALUE  ( 32'h0000_0000     )
    , .WRITE_MASK   ( 32'h0000_0000     )
    )
    u_mhartid
    ( .clk            ( clk                 )
    , .reset          ( reset               )
    , .read_address   ( csr_request.address )
    , .read_value     ( mhartid_read_value  )
    , .csr_wb_request ( csr_wb_request      )
    );

  // async read
  assign csr_data = mscratch_read_value | mhartid_read_value;

endmodule
