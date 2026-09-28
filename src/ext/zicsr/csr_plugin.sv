`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

// instantiate this to declare a CSR called `NAME`, living at `ADDRESS` with the corresponding
// `RESET_VALUE` and `WRITE_MASK`
module csr_plugin
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

  data_t raw_value;
  data_t clean_value; // after applying the writemask

  always_ff @(posedge clk)
    if (reset)
      raw_value <= RESET_VALUE;
    else if (csr_wb_request.write_enable && (csr_wb_request.address == ADDRESS))
      raw_value <= csr_wb_request.data;

  assign clean_value = (raw_value & WRITE_MASK) | (RESET_VALUE & ~WRITE_MASK);

  assign read_value = (read_address == ADDRESS) ? clean_value : data_t'(0);

endmodule
