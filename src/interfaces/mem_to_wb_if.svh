`ifndef MEM_TO_WB_IF__HG
`define MEM_TO_WB_IF__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

typedef struct packed {
  result_src_t result_src;
  logic        reg_write;
  data_t       alu_result;
  reg_t        rd;
  addr_t       pc_cur;
  addr_t       pc_plus_4;
  logic [2:0]  funct3;
`ifdef UTOSS_RISCV__ZICSR_ENABLED
  ext__zicsr__types::csr_request_t csr_request;
  data_t                           csr_data;
`endif
} mem_to_wb_t;

`endif
