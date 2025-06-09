`timescale 1ns/1ps

module tb_registerFile;

  //DUT inputs
  logic [4:0] Addr1, Addr2, Addr3;
  logic clk;
  logic regWrite;
  logic [31:0] dataIn;

  //DUT outputs
  logic [31:0] baseAddr, writeData;

  //Instantiate the DUT
  registerFile dut (
    .Addr1(Addr1),
    .Addr2(Addr2),
    .Addr3(Addr3),
    .clk(clk),
    .regWrite(regWrite),
    .dataIn(dataIn),
    .baseAddr(baseAddr),
    .writeData(writeData)
  );

  //Clock generation
  always #5 clk = ~clk;

  initial begin
    $display("Starting Register File Testbench...");
    clk = 0;

    // STEP 0: Manual initialization of RF memory (reg 5 and 10)
    dut.RFMem[5] = 32'hDEADBEEF; //preloads memory values into registers
    dut.RFMem[10] = 32'hCAFEBABE;

	 //CASE I - reading
    //set Addr1 = 5 and Addr2 = 10 to read from registers 5 and 10
    Addr1 = 5;
    Addr2 = 10;
    Addr3 = 0; 
    dataIn = 0;
    regWrite = 0;

    @(posedge clk); //waits for positive clock edge
    #1; // wait for output to stabilize after posedge
    assert(baseAddr == 32'hDEADBEEF) else $fatal("current baseAddr output: %h; expected baseAddr output: DEADBEEF", baseAddr);
    assert(writeData == 32'hCAFEBABE) else $fatal("current writeData output: %h; expected writeData output: CAFEBABE", writeData);

    //CASE 2 - Write to reg 15
    Addr3 = 15;
    dataIn = 32'h12345678;
    regWrite = 1;
 
    @(posedge clk); //wait one clock cycle
    regWrite = 0; //de-assert write

    #1; //wait for written data to stabilize
    assert(dut.RFMem[15] == 32'h12345678) else $fatal("WRITE FAILED: current reg 15 output: %h; expected reg 15 output: 12345678", dut.RFMem[15]);
    $display("PASS: Write to register verified");
	 
	 //CASE 3 - Write to reg 0
	 Addr3 = 0;
	 dataIn = 32'h12345678;
	 
	 @(posedge clk); //wait one clock cycle
	 regWrite = 0; //de-assert write
	 
    #1; //wait for written data to stabilize
    assert(dut.RFMem[0] == 0) else $fatal("WRITE FAILED: current reg 0 output: %h; expected reg 15 output: 0", dut.RFMem[0]);	 
    $display("PASS: Write to register verified");

    $finish;
  end
  
  initial begin //generate waveform
	 
	$dumpfile("RFTB.vcd");
	$dumpvars(0, tb_registerFile);
	 
  end

endmodule
