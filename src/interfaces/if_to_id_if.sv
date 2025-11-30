`include "src/headers/params.vh"
`include "src/headers/types.svh"

interface if_to_id_if (input clk);
    instr_t instruction;

    modport Fetch(
        input clk,
        output instruction
    );

    modport Decode(
        input clk,
        input instruction
    );

endinterface
