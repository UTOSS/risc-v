`ifndef EX_TO_MEM_IF__HG
`define EX_TO_MEM_IF__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  logic        reg_write;
  logic        mem_write;
  result_src_t result_src;
  data_t       alu_result;
  data_t       write_data_e;
  data_t       csr_read_data;
  logic [2:0]  funct3;
  logic [4:0]  rd;
  addr_t       pc_cur;
  addr_t       pc_plus_4;
} ex_to_mem_t;

`endif
