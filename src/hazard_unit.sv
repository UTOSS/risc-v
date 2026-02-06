module hazard_unit
  ( input wire clk
  , input wire Rs1E
  , input wire RdM
  , input wire RdW
  , input wire RegWriteM
  , input wire [1:0] ResultSrcE
  , input wire Rs1D
  , input wire Rs2D
  , input wire RdE
  , input wire PCSrcE
  , output reg [1:0] ForwardAE
  , output reg lwStall
  , output reg StallF
  , output reg StallD
  , output reg FlushD
  , output reg Flush
  );

  wire ResultSrcE0;
  assign ResultSrcE0 = ResultSrcE[0];

//Forward
  always @ (posedge clk) begin
    if (((Rs1E == RdM) & RegWriteM) & (Rs1E != 0)) ForwardAE <= 2'b10;
    else if (((Rs1E == RdW) & RegWriteM) & (Rs1E != 0)) ForwardAE <= 2'b01;
    else ForwardAE <= 2'b00;
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
