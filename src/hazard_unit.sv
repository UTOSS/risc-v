`include "src/headers/types.svh"

module hazard_unit
  ( input wire clk
  , input wire Rs1E
  , input wire Rs2E
  , input wire RdM
  , input wire RdW
  , input wire RegWriteM
  , input wire RegWriteW
  , input wire [1:0] ResultSrcE
  , input wire Rs1D
  , input wire Rs2D
  , input wire RdE
  , input wire PCSrcE
  , output hazard_forward_a_t ForwardAE
  , output hazard_forward_b_t ForwardBE
  , output reg lwStall
  , output reg StallF
  , output reg StallD
  , output reg FlushD
  , output reg FlushE
  );

  wire ResultSrcE0;
  assign ResultSrcE0 = ResultSrcE[0];

//Forward
// TODO: check if we need to do this combinationally
  always @ (posedge clk) begin
    if (((Rs1E == RdM) & RegWriteM) & (Rs1E != 0))
      ForwardAE <= HAZARD_FORWARD_A__MEMORY_ALU_RESULT;
    else if (((Rs1E == RdW) & RegWriteM) & (Rs1E != 0))
      ForwardAE <= HAZARD_FORWARD_A__WRITE_BACK_RESULT;
    else
      ForwardAE <= HAZARD_FORWARD_A__EXECUTE_RD1;
  end

  always @ (posedge clk) begin
    if (Rs2E != 0 && Rs2E == RdM && RegWriteW)
      ForwardBE <= HAZARD_FORWARD_B__MEMORY_ALU_RESULT;
    else if (Rs2E != 0 && Rs2E == RdW && RegWriteM)
      ForwardBE <= HAZARD_FORWARD_B__WRITE_BACK_RESULT;
    else
      ForwardBE <= HAZARD_FORWARD_B__EXECUTE_RD2;
  end

//Stall when a load hazard occurs
  always @ (posedge clk) begin
    lwStall <= ResultSrcE0 & ((Rs1D == RdE) | (Rs2D == RdE));
    StallF <= lwStall;
    StallD <= lwStall;
  end

//Flush when a control hazard occurs
  always @ (posedge clk) begin
    FlushD <= PCSrcE;
    FlushE <= lwStall | PCSrcE;
  end

endmodule
