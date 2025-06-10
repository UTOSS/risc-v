//to test ControlFSM, put this file, ControlFSM.v and params.vh in the same folder, and add this following line to the ControlFSM.v before running the test
//`include "params.vh"
`timescale 1ns / 1ps

module ControlFSM_tb;

  // Inputs
  logic CLOCK_50;
  logic reset;
  logic [6:0] opcode;

  // Outputs
  logic AdrSrc;
  logic IRWrite;
  logic RegWrite;
  logic PCUpdate;
  logic MemWrite;
  logic Branch;
  logic [1:0] ALUSrcA;
  logic [1:0] ALUSrcB;
  logic [2:0] ALUOp;
  logic [1:0] ResultSrc;
  logic [3:0] FSMState;
  
	
    ControlFSM control_fsm (
        .opcode(opcode),
		.clk(CLOCK_50),//using CLOCK_50 as the clk
        .reset(reset),
        .AdrSrc(AdrSrc),
        .IRWrite(IRWrite),
		.RegWrite(RegWrite),
		.PCUpdate(PCUpdate),
		.MemWrite(MemWrite),
		.Branch(Branch),
		.ALUSrcA(ALUSrcA),
		.ALUSrcB(ALUSrcB),
		.ALUOp(ALUOp),
		.ResultSrc(ResultSrc),
		.FSMState(FSMState)
    );
	
	parameter CLOCK_PERIOD = 10;
	initial begin
        CLOCK_50 <= 1'b0;
	end // initial
	always @ (*)
	begin : Clock_Generator
		#((CLOCK_PERIOD) / 2) CLOCK_50 <= ~CLOCK_50;
	end

	task apply_opcode(input [6:0] opc);
    begin
      opcode = opc;
      #10; // Wait for state transition
$display("Time: %0t | State: %0d | Opcode: %b\n\
AdrSrc: %b | IRWrite: %b | RegWrite: %b | PCUpdate: %b | MemWrite: %b | Branch: %b\n\
ALUSrcA: %b | ALUSrcB: %b | ALUOp: %b | ResultSrc: %b",
  $time, FSMState, opcode,
  AdrSrc, IRWrite, RegWrite, PCUpdate, MemWrite, Branch,
  ALUSrcA, ALUSrcB, ALUOp, ResultSrc);
    end
	endtask
	
	task print;
	begin
	$display("Time: %0t | State: %0d | Opcode: %b\n\
AdrSrc: %b | IRWrite: %b | RegWrite: %b | PCUpdate: %b | MemWrite: %b | Branch: %b\n\
ALUSrcA: %b | ALUSrcB: %b | ALUOp: %b | ResultSrc: %b",
  $time, FSMState, opcode,
  AdrSrc, IRWrite, RegWrite, PCUpdate, MemWrite, Branch,
  ALUSrcA, ALUSrcB, ALUOp, ResultSrc);
	end
	endtask

      integer i;

  initial begin
    // Initialize inputs
    reset = 1;
    opcode = 7'b0000000;

    // Apply reset
    #10;
    reset = 0;

    // Apply different opcodes and observe transitions
    apply_opcode(7'b0110011); // R-type
  for (i = 0; i < 3; i = i + 1) begin
    #10;
    print();
  end	
  
    apply_opcode(7'b0010011); // I-type
  for (i = 0; i < 3; i = i + 1) begin
    #10;
    print();
  end 

    apply_opcode(7'b0000011); // Load
  for (i = 0; i < 4; i = i + 1) begin
    #10;
    print();
  end

    apply_opcode(7'b0100011); // Store
  for (i = 0; i < 4; i = i + 1) begin
    #10;
    print();
  end

    apply_opcode(7'b1101111); // JAL
  for (i = 0; i < 3; i = i + 1) begin
    #10;
    print();
  end

    apply_opcode(7'b1100011); // BEQ
  for (i = 0; i < 3; i = i + 1) begin
	#10;
    print();
  end

    // Done
    #20;
    $finish;
	
	end
	
endmodule