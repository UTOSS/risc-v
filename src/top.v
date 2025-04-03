`include "src/types.svh"

module top ( input wire clk
           , input wire reset
           );

  wire    cfsm__pc_update;
  wire    cfsm__pc_src;
  instr_t instr;
  imm_t   imm_ext;

  wire __tmp_AdrSrc
     , __tmp_IRWrite
     , __tmp_RegWrite
     , __tmp_MemWrite
     , __tmp_Branch;
  wire [1:0] __tmp_ALUSrcA
           , __tmp_ALUSrcB;
  wire [2:0] __tmp_ALUOp;
  wire [1:0] __tmp_ResultSrc;
  wire [3:0] __tmp_FSMState;

  ControlFSM control_fsm
    ( .opcode    ( 7'b0000000      )
    , .clk       ( clk             )
    , .reset     ( reset           )
    , .AdrSrc    ( __tmp_AdrSrc    )
    , .IRWrite   ( __tmp_IRWrite   )
    , .RegWrite  ( __tmp_RegWrite  )
    , .PCUpdate  ( cfsm__pc_update )
    , .MemWrite  ( __tmp_MemWrite  )
    , .Branch    ( __tmp_Branch    )
    , .ALUSrcA   ( __tmp_ALUSrcA   )
    , .ALUSrcB   ( __tmp_ALUSrcB   )
    , .ALUOp     ( __tmp_ALUOp     )
    , .ResultSrc ( __tmp_ResultSrc )
    , .FSMState  ( __tmp_FSMState  )
    );

  fetch fetch
    ( .clk             ( clk             )
    , .reset           ( reset           )
    , .cfsm__pc_update ( cfsm__pc_update )
    , .cfsm__pc_src    ( cfsm__pc_src    )
    , .imm_ext         ( imm_ext         )
    , .instr           ( instr           )
    );

  extend extend
    ( .in      ( instr[31:20] )
    , .imm_ext ( imm_ext      )
    );

endmodule
