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

  data_t csrs     [`NUMBER_OF_CSRS];
  data_t next_csrs[`NUMBER_OF_CSRS];

  // asynchronous read
  assign csr_data.value = csrs[csr_request.address];

  for (genvar i = 0; i < `NUMBER_OF_CSRS; i++) begin: l_csrs
    always_comb
      if (reset)
        next_csrs[i] = data_t'(0);
      else if (csr_wb_request.write_enable && (csr_wb_request.address == i))
        next_csrs[i] = csr_wb_request.data;
      else
        next_csrs[i] = csrs[i];

    always_ff @(posedge clk)
      csrs[i] <= next_csrs[i];
  end

endmodule
