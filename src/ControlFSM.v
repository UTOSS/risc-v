//created by Joonseo Park, for University of Toronto Open Source Society
//A Moore Type Finite State Machine for the RV32I Microprocessor Control Unit

module ControlFSM(

	input wire [6:0] opcode,
	input wire clk,
	input wire reset,
	output reg AdrSrc,
	output reg IRWrite,
	output reg RegWrite,
	output reg PCUpdate,
	output reg MemWrite,
	output reg Branch,
	output reg [1:0] ALUSrcA,
	output reg [1:0] ALUSrcB,
	output reg [2:0] ALUOp, //to ALU Decoder
	output reg [1:0] ResultSrc,
	output reg [3:0] FSMState

);

	//parameterize states (binary encoding)
	//in later systemverilog implementation, change to enum
	parameter FETCH = 4'b0000;
	parameter DECODE = 4'b0001;
	parameter EXECUTER = 4'b0010;
	parameter UNCONDJUMP = 4'b0011;
	parameter EXECUTEI = 4'b0100;
	parameter MEMADR = 4'b0101;
	parameter ALUWB = 4'b0110;
	parameter MEMWRITE = 4'b0111;
	parameter MEMREAD = 4'b1000;
	parameter MEMWB = 4'b1001;
	parameter BRANCHIFEQ = 4'b1010;

	//declare state registers
	reg [3:0] current_state, next_state;

	//Next state logic
	always@(*)begin

		case(current_state)

			FETCH: next_state = DECODE;

			DECODE: begin

				if (opcode == JType) next_state = UNCONDJUMP;

				else if (opcode == RType) next_state = EXECUTER;

				else if (opcode == IType_logic) next_state = EXECUTEI;

				else if (opcode == IType_load || opcode == SType) next_state = MEMADR;

				else if (opcode == BType) next_state = BRANCHIFEQ;

				else next_state = DECODE;

			end

			UNCONDJUMP: next_state = ALUWB;

			EXECUTER: next_state = ALUWB;

			EXECUTEI: next_state = ALUWB;

			MEMADR: begin

				if (opcode == IType_load) next_state = MEMREAD;

				else if (opcode == SType) next_state = MEMWRITE;

				else next_state = MEMADR;

			end

			BRANCHIFEQ: next_state = FETCH;

			ALUWB: next_state = FETCH;

			MEMREAD: next_state = MEMWB;

			MEMWRITE: next_state = FETCH;

			MEMWB: next_state = FETCH;

			default: next_state = FETCH;

		endcase

	end

	//output logic
	always@(posedge clk) begin

		FSMState <= current_state;

		case(current_state)

			FETCH: begin

				AdrSrc <= 1'b0;
				IRWrite <= 1'b1;

			end

			DECODE: begin

				ALUSrcA <= 2'b01;
				ALUSrcB <= 2'b01;
				ALUOp <= 2'b00;

			end

			EXECUTER: begin

				ALUSrcA <= 2'b10;
				ALUSrcB <= 2'b00;
				ALUOp <= 2'b10;

			end

			EXECUTEI: begin

				ALUSrcA <= 2'b10;
				ALUSrcB <= 2'b01;
				ALUOp <= 2'b11;

			end

			UNCONDJUMP: begin

				ALUSrcA <= 2'b01;
				ALUSrcB <= 2'b10;
				ALUOp <= 2'b00;
				ResultSrc <= 2'b00;
				PCUpdate <= 1'b1;

			end

			MEMADR: begin

				ALUSrcA <= 2'b10;
				ALUSrcB <= 2'b01;
				ALUOp <= 2'b00;

			end

			BRANCHIFEQ: begin

				ALUSrcA <= 2'b10;
				ALUSrcB <= 2'b00;
				ALUOp <= 2'b01;
				ResultSrc <= 2'b00;
				Branch <= 1'b1;

			end

			ALUWB: begin

				ResultSrc <= 2'b00;
				RegWrite <= 1'b1;

			end

			MEMWRITE: begin

				ResultSrc <= 2'b00;
				AdrSrc <= 1'b1;
				MemWrite <= 1'b1;

			end

			MEMREAD: begin

				ResultSrc <= 2'b00;
				AdrSrc <= 1'b1;

			end

			MEMWB: begin

				ResultSrc <= 2'b01;
				RegWrite <= 1'b1;

			end

			default: begin //by default, we return to FETCH state

				AdrSrc <= 1'b0;
				IRWrite <= 1'b1;

			end


		endcase

	end

	//State transition logic (sequential)
	always @ (posedge clk) begin

		if (reset) current_state <= FETCH;

		else current_state <= next_state;

	end


endmodule
