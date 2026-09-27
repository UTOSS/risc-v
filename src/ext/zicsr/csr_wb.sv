`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

module csr_wb
  /* verilator lint_off UNUSEDSIGNAL */
  ( input  ext__zicsr__types::csr_request_t    csr_request
  /* verilator lint_on UNUSEDSIGNAL */
  , input  ext__zicsr__types::csr_data_t       csr_data
  , output ext__zicsr__types::csr_wb_request_t csr_wb_request
  );

  import ext__zicsr__types::*;

  assign csr_wb_request.address      = csr_request.address;
  assign csr_wb_request.write_enable = csr_request.write_intent;

  always_comb
    case (csr_request.op)
      CSR_OP__WRITE: csr_wb_request.data = csr_request.operand;
      CSR_OP__SET:   csr_wb_request.data = csr_data.value | csr_request.operand;
      CSR_OP__CLEAR: csr_wb_request.data = csr_data.value & ~csr_request.operand;
      default:       csr_wb_request.data = csr_data.value;
    endcase

endmodule
