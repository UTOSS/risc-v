`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

// instantiate this to declare a CSR called `NAME`, living at `ADDRESS` with the corresponding
// `RESET_VALUE` and `WRITE_MASK`
module csr_plugin_basic
  /* verilator lint_off UNUSEDPARAM */
  #(parameter string     NAME         = ""
  /* verilator lint_on UNUSEDPARAM */
  , parameter bit [11:0] ADDRESS      = 12'h000
  , parameter bit [31:0] RESET_VALUE  = 32'h0000_0000
  , parameter bit [31:0] WRITE_MASK   = 32'hffff_ffff
  )
  ( input logic clk
  , input logic reset

  , input  csr_addr_t                          read_address
  , output data_t                              read_value

  , input  ext__zicsr__types::csr_wb_request_t csr_wb_request
  );

  csr_hw_request_if blank_csr_hw_request();
  assign blank_csr_hw_request.write_data = '0;
  assign blank_csr_hw_request.write_enable = '0;

  csr_plugin
    #(.NAME        ( NAME        )
    , .ADDRESS     ( ADDRESS     )
    , .RESET_VALUE ( RESET_VALUE )
    , .WRITE_MASK  ( WRITE_MASK  )
    )
    u_csr_plugin
      ( .clk          ( clk   )
      , .reset        ( reset )

      , .read_address ( read_address )
      , .read_value   ( read_value   )

      , .csr_hw_request ( blank_csr_hw_request )
      , .csr_wb_request ( csr_wb_request       )
      );

endmodule
