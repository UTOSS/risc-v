//created by Joonseo Park, for University of Toronto Open Source Society
//A Moore Type Finite State Machine for the RV32I Microprocessor Control Unit

`include "src/types.svh"

module ControlFSM(

	input opcode_t opcode,
	input wire clk,
	input wire reset,
  input wire zero_flag,
	output adr_src_t AdrSrc,
	output reg IRWrite,
	output reg RegWrite,
	output reg PCUpdate,
  output pc_src_t pc_src,
	output reg MemWrite,
	output reg Branch,
	output alu_src_a_t ALUSrcA,
	output alu_src_b_t ALUSrcB,
	output reg [2:0] ALUOp, //to ALU Decoder
	output result_src_t ResultSrc,
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
	always@(*) begin
    Branch <= 1'b0;
    pc_src <= 1'b0;
    PCUpdate <= 1'b0;
    IRWrite <= 1'b0;
    MemWrite <= 1'b0;

		FSMState <= current_state;

		case(current_state)

			FETCH: begin

				AdrSrc <= ADR_SRC__PC;
				IRWrite <= 1'b1;
        PCUpdate <= 1'b1;

			end

			DECODE: begin

				ALUSrcA <= ALU_SRC_A__OLD_PC;
				ALUSrcB <= ALU_SRC_B__IMM_EXT;
				ALUOp <= 2'b00;

			end

			EXECUTER: begin

				ALUSrcA <= ALU_SRC_A__RD1;
				ALUSrcB <= ALU_SRC_B__RD2;
				ALUOp <= 2'b10;

			end

			EXECUTEI: begin

				ALUSrcA <= ALU_SRC_A__RD1;
				ALUSrcB <= ALU_SRC_B__IMM_EXT;
				ALUOp <= 2'b11;

			end

			UNCONDJUMP: begin

				ALUSrcA <= ALU_SRC_A__OLD_PC;
				ALUSrcB <= ALU_SRC_B__4;
				ALUOp <= 2'b00;
				ResultSrc <= RESULT_SRC__ALU_OUT;
        PCUpdate <= 1'b1;

			end

			MEMADR: begin

				ALUSrcA <= ALU_SRC_A__RD1;
				ALUSrcB <= ALU_SRC_B__IMM_EXT;
				ALUOp <= 2'b00;

			end

			BRANCHIFEQ: begin

				ALUSrcA <= ALU_SRC_A__RD1;
				ALUSrcB <= ALU_SRC_B__RD2;
				ALUOp <= 2'b01;
				ResultSrc <= RESULT_SRC__ALU_OUT;
				Branch <= 1'b1;
        pc_src <= zero_flag ? PC_SRC__JUMP : PC_SRC__INCREMENT;
        PCUpdate <= 1'b1;

			end

			ALUWB: begin

				ResultSrc <= RESULT_SRC__ALU_OUT;
				RegWrite <= 1'b1;

			end

			MEMWRITE: begin

				ResultSrc <= RESULT_SRC__ALU_OUT;
				AdrSrc <= ADR_SRC__RESULT;
				MemWrite <= 1'b1;

			end

			MEMREAD: begin

				ResultSrc <= RESULT_SRC__ALU_OUT;
				AdrSrc <= ADR_SRC__RESULT;

			end

			MEMWB: begin

				ResultSrc <= RESULT_SRC__DATA;
				RegWrite <= 1'b1;

			end

			default: begin //by default, we return to FETCH state

				AdrSrc <= ADR_SRC__PC;
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
