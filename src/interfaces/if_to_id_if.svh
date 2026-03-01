`ifndef IF_TO_ID_IF__HG
`define IF_TO_ID_IF__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  instr_t instruction;
  addr_t  pc_cur;
  addr_t  pc_plus_4;
} if_to_id_t;

`endif
