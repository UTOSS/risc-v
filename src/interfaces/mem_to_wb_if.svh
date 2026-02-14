`ifndef MEM_TO_WB_IF__HG
`define MEM_TO_WB_IF__HG

typedef struct packed {
  result_src_t cfsm__result_src;
  logic        RegWriteW;
  data_t       read_data;
  data_t       alu_result;
  logic [4:0]  rd;
} mem_to_wb_t;

`endif
