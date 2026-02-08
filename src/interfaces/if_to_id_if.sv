`include "src/headers/params.svh"
`include "src/headers/types.svh"

interface if_to_id_if;
  instr_t instruction;
  addr_t pc_cur;

  modport Fetch
    ( output instruction
    , output pc_cur
    );

  modport Decode
    ( input instruction
    , input pc_cur
    );

endinterface
