`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  // adr_src_t AdrSrc;
  // pc_src_t pc_src;
  // logic IRWrite;
  // logic [3:0] MemWrite;
  logic        RegWrite;
  result_src_t ResultSrc;
  // logic [3:0] MemWriteByteAddress;
  logic [2:0]  funct3;

  data_t      alu_result;
  logic [4:0] rd;
  // data_t rd2;
  addr_t      pc_cur;
} ex_to_mem_t;
