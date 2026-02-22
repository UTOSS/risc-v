`ifndef EX_TO_MEM_IF__HG
`define EX_TO_MEM_IF__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  // adr_src_t AdrSrc;
  // pc_src_t pc_src;
  // logic IRWrite;
  // logic [3:0] MemWrite;
  logic                   RegWrite;
  logic                   MemWrite;
  write_back_result_src_t ResultSrc;
  // logic [3:0] MemWriteByteAddress;
  data_t                  alu_result;
  data_t                  WriteDataE;
  logic [4:0]             rd;
  // data_t rd2;
  addr_t                  pc_cur;
  addr_t                  pc_plus_4;
} ex_to_mem_t;

`endif
