`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

module csr_data
  ( input logic clk
  , input logic reset

  /* verilator lint_off UNUSEDSIGNAL */
  , input  ext__zicsr__types::csr_request_t    csr_request
  /* verilator lint_on UNUSEDSIGNAL */
  , input  ext__zicsr__types::csr_wb_request_t csr_wb_request
  , output ext__zicsr__types::csr_data_t       csr_data
  );

  data_t csrs [0:`NUMBER_OF_CSRS - 1];

  // asynchronous read
  assign csr_data.value = csrs[csr_request.address];

  always_ff @(posedge clk)
    if (reset)                            csrs                         <= '{default: data_t'(0)};
    else if (csr_wb_request.write_enable) csrs[csr_wb_request.address] <= csr_wb_request.data;

endmodule
