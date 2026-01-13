module registerFile
  ( input  [4:0]  Addr1
  , input  [4:0]  Addr2
  , input  [4:0]  Addr3
  , input         clk
  , input         regWrite
  , input  [31:0] dataIn
  , input         reset
  , output wire [31:0] baseAddr
  , output wire [31:0] writeData
  , output logic [31:0] dbg_regs [0:31]  
  );

  reg [31:0] RFMem [0:31] /* synthesis ramstyle = M10K*/;

  assign baseAddr  = (Addr1 == 5'd0) ? 32'd0 : RFMem[Addr1];
  assign writeData = (Addr2 == 5'd0) ? 32'd0 : RFMem[Addr2];

  genvar i;
  generate
    for (i=0;i<32;i=i+1) begin : DBG
      always_comb dbg_regs[i] = (i==0) ? 32'd0 : RFMem[i];
    end
  endgenerate

  always @(posedge clk) begin
    if (reset) begin
`ifndef TESTBENCH
      integer k;
      for (k = 0; k < 32; k = k + 1) begin
        RFMem[k] <= 32'b0;
      end
`else
      RFMem[0] <= 32'b0;
`endif
    end else if (regWrite && Addr3 != 0) begin
      RFMem[Addr3] <= dataIn;
    end
  end
 endmodule