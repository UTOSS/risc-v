`ifndef MEM_TO_WB_IF__HG
`define MEM_TO_WB_IF__HG

typedef struct packed {
  result_src_t result_src;
  logic        reg_write;
  data_t       alu_result;
  data_t       csr_read_data;
  logic [4:0]  rd;
  addr_t       pc_cur;
  addr_t       pc_plus_4;
  logic [2:0]  funct3;
} mem_to_wb_t;

`endif
