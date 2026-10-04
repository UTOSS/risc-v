`include "src/ext/zicsr/types.svh"

module ecall_processor
  ( input logic enable

  , input addr_t pc

  , csr_hw_request_if.hw mepc_hw_request
  , csr_hw_request_if.hw mcause_hw_request
  );

  assign mepc_hw_request.write_enable = enable;
  assign mepc_hw_request.write_data   = enable ? pc : '0;

  assign mcause_hw_request.write_enable = enable;
  assign mcause_hw_request.write_data   =
    enable ? data_t'(ext__zicsr__types::CSR_MCAUSE__EXCEPTION_CODE__ECALL) : '0;

endmodule
