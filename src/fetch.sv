/* sandbox module for fetching instructions */

`include "src/utils.svh"
`include "src/types.svh"

module fetch ( input  wire    clk
             , input  wire    reset
             , input  wire    cfsm__pc_update
             , input  wire    cfsm__pc_src
             , input  imm_t   imm_ext
             , output instr_t instr
             );

  addr_t pc_plus_4, pc_target, pc_next, pc_cur;

  register #( .DATA_TYPE( addr_t ) ) program_counter
    ( .clk      ( clk             )
    , .reset    ( reset           )
    , .en       ( cfsm__pc_update )
    , .data_in  ( pc_next         )
    , .data_out ( pc_cur          )
    );

  adder #( .WIDTH( `PROCESSOR_BITNESS ) ) program_counter_plus_4
    ( .lhs ( pc_cur    )
    , .rhs ( 32'h4     )
    , .out ( pc_plus_4 )
    );

  MA instruction_memory
    ( .A   ( pc_cur       )
    , .WD  ( 32'hxxxxxxxx )
    , .WE  ( `FALSE       )
    , .CLK ( clk          )
    , .RD  ( instr        )
    );

  adder #( .WIDTH( `PROCESSOR_BITNESS ) ) program_counter_target
    ( .lhs ( pc_cur    )
    , .rhs ( imm_ext   )
    , .out ( pc_target )
    );

  // Continuous assignment of array concatenation is not yet supported.
  addr_t pc_mux_in [1:0];
  assign pc_mux_in[0] = pc_plus_4;
  assign pc_mux_in[1] = pc_target;
  mux #( .INPUT_COUNT ( 2 ), .INPUT_WIDTH ( `PROCESSOR_BITNESS ) ) pc_mux
    ( .sel ( cfsm__pc_src )
    , .in  ( pc_mux_in    )
    , .out ( pc_next      )
    );

endmodule
