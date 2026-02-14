`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  instr_t instruction;
  addr_t  pc_cur;
} if_to_id_t;
