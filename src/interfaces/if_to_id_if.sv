`include "src/headers/params.svh"
`include "src/headers/types.svh"

interface if_to_id_if;
  instr_t instruction;

  modport Fetch
    ( output instruction
    );

  modport Decode
    ( input instruction
    );

endinterface
