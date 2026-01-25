//Created by Joonseo Park
//The register file holds the source and destination registers specified by instruction fields

//REGISTERS:
//baseAddr --> holds data read line #1; the output of rs1
//writeData --> holds data read line #2; the output of rs2
//rs1 --> a register inside RF memory, holding base address
//rs2 --> a register inside RF memory, holding data to be written into destination register
//rd --> a register inside RF memory, holding address of register to be written into

module registerFile
  ( input  [4:0]  Addr1
  , input  [4:0]  Addr2
  , input  [4:0]  Addr3
  , input  clk
  , input  regWrite
  , input  [31:0] dataIn
  , input  reset
  , output wire [31:0] baseAddr
  , output wire [31:0] writeData
  , output logic [31:0] dbg_regs [0:31]   // NEW, added for UART debugging
  );

  reg [31:0] RFMem [0:31] /* synthesis ramstyle = M10K*/;

  assign baseAddr  = (Addr1 == 5'd0) ? 32'd0 : RFMem[Addr1];
  assign writeData = (Addr2 == 5'd0) ? 32'd0 : RFMem[Addr2];

always @(*) begin
    dbg_regs[0] = 32'd0;
    for (int i = 1; i < 32; i++) begin
        dbg_regs[i] = RFMem[i];
    end
end


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
