/* sandbox module for fetching instructions */

`include "src/utils.svh"
`include "src/types.svh"

module fetch ( input  wire    clk
             , input  wire    reset
             , input  wire    cfsm__pc_update
             , output instr_t instr
             );

  addr_t pc_next, pc_cur;

  register #( .DATA_TYPE( addr_t ) ) program_counter
    ( .clk      ( clk             )
    , .reset    ( reset           )
    , .en       ( cfsm__pc_update )
    , .data_in  ( pc_next         )
    , .data_out ( pc_cur          )
    );

  adder #( .WIDTH( `PROCESSOR_BITNESS ) ) program_counter_plus_4
    ( .clk ( clk       )
    , .en  ( `TRUE     )
    , .lhs ( pc_cur    )
    , .rhs ( 32'h4     )
    , .out ( pc_next   )
    );

  MA instruction_memory
    ( .A   ( pc_cur       )
    , .WD  ( 32'hxxxxxxxx )
    , .WE  ( `FALSE       )
    , .CLK ( clk          )
    , .RD  ( instr        )
    );

endmodule
