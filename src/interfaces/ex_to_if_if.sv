`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  pc_src_t pc_src;
  addr_t   pc_old;
  imm_t    imm_ext;
  addr_t   alu_result_for_pc;
} ex_to_if_t;
