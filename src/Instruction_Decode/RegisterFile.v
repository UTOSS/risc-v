//Created by Joonseo Park
//The register file holds the source and destination registers specified by instruction fields

//REGISTERS:
//baseAddr --> holds data read line #1; the output of rs1
//writeData --> holds data read line #2; the output of rs2
//rs1 --> a register inside RF memory, holding base address
//rs2 --> a register inside RF memory, holding data to be written into destination register
//rd --> a register inside RF memory, holding address of register to be written into

module registerFile
  ( input [4:0] Addr1 //rs1 field (holds addr of one of 32 registers) - first source register
  , input [4:0] Addr2 //rs2 field - second source register (holds data to be stored)
  , input [4:0] Addr3 //rd field - desination register
  , input clk
  , input regWrite
  , input [31:0] dataIn
  , input reset
  , output wire [31:0] baseAddr //data read line #1 - from first source register
  , output wire [31:0] writeData //data read line #2 - from second source register
  );

  //declare 32 registers in Register File, with 32 bits each 32 bits deep (32 addresses) and 32 bits
  //wide (32 bits at each register) note that RFMem[0:31] means there are 32 elements (with addr for
  //each element), each of which are 32-bit regs
  reg [31:0] RFMem [0:31] /* synthesis ramstyle = M10K*/;

  // x0 always 0, read out 32-bit contents of rs1 register
  assign baseAddr  = (Addr1 == 5'd0) ? 32'd0 : RFMem[Addr1];

  // x0 always 0 on read, read out 32-bit contents of rs2 register
  assign writeData = (Addr2 == 5'd0) ? 32'd0 : RFMem[Addr2];

  always @(posedge clk) begin

    if (reset) RFMem[0] <= 0; //register r0 should always remain at 0

    if (regWrite && Addr3 != 0) begin

      RFMem[Addr3] <= dataIn; //write into destination register if RegWrite = 1

    end

  end

endmodule
