`include "src/types.svh"

module top ( input wire clk
           , input wire reset
           );

  wire cfsm__pc_update;
  instr_t instr;

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
    , .instr           ( instr           )
    );

  MA memory_access (
      .A   (baseAddr),        //baseAddr is from Instruction_Decode.v it sounded like it matches with the module paramters in MA
      .WD  (writeData),       //same as above
      .WE  (MemWrite),        //same as above but from ControlFSM interacting with MA e.g. when memWrite = 1
      .CLK (clk),
      .RD  (ma__readdata)     //just left this because i dont think its connected to anything ?
  );

  Instruction_Decode instruction_decode (
      .instr      (instr),
      .clk        (clk),
      .reset      (reset),
      .ResultData (ResultData),   
      .AdrSrc     (AdrSrc),
      .IRWrite    (IRWrite),
      .PCUpdate   (PCUpdate),     
      .MemWrite   (MemWrite),
      .Branch     (Branch),
      .ALUSrcA    (ALUSrcA),
      .ALUSrcB    (ALUSrcB),
      .ResultSrc  (ResultSrc),
      .ALUControl (ALUControl),
      .baseAddr   (baseAddr),     
      .writeData  (writeData)   
  );

endmodule