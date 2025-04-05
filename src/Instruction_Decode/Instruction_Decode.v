`include "src/params.vh"
`include "src/types.svh"

module Instruction_Decode(

	input wire [31:0] instr,
	input wire clk,
	input wire reset,
	input wire [31:0] ResultData,
  output opcode_t opcode,
	output wire [3:0] ALUControl,
	output wire [31:0] baseAddr,
	output wire [31:0] writeData,
  output imm_t imm_ext
);

	wire [1:0] ALUOp; //wire from Control FSM to ALU Decoder
	wire RegWrite;
	reg [2:0] funct3;
	reg [6:0] funct7;
	reg [4:0] rd, rs1, rs2;
	wire [3:0] state;

  assign opcode = instr[6:0];

	//combinational logic for extracting funct3 and funct7[5] for ALU Decoder input
	always@(*) begin

		if (opcode == RType) begin //R-Type

			funct3 = instr[14:12];
			funct7 = instr[31:25];

		end

		else if (opcode == IType) begin  //I-Type (excluding lw)

			funct3 = instr[14:12];
			funct7 = 7'b0;

		end

		else begin //lw, sw, jal, and beq instructions:

			funct3 = 3'b000;
			funct7 = 7'b0;

		end

	end

	//logic for extracting rs1, rs2, and rd registers from 32-bit instruction field
	//The logic depends on the instruction type
	always@(*) begin

		if (opcode == RType) begin //R-Type

			rd = instr[11:7];
			rs1 = instr[19:15];
			rs2 = instr[24:20];

		end

		else if (opcode == IType || opcode == LWType) begin //I-Type (where lw is I type)

			rd = instr[11:7];
			rs1 = instr[19:15];
			rs2 = 5'b00000;

		end

		else if (opcode == SType || opcode == BType) begin //S-type and B-Type

			rd = 5'b00000;
			rs1 = instr[19:15];
			rs2 = instr[24:20];

		end

		else if (opcode == JType) begin //J-Type

			rd = instr[11:7];
			rs1 = 5'b00000;
			rs2 = 5'b00000;

		end

		else begin

			rd = 5'b00000;
			rs1 = 5'b00000;
			rs2 = 5'b00000;

		end

	end

	// case statement for choosing 32-bit immediate format; based on opcode
  // this is essentially the extend module of the processor
	always@(*) begin
		case(opcode)
			IType  : imm_ext = {{20{instr[31]}}, instr[31:20]};
			LWType : imm_ext = {{20{instr[31]}}, instr[31:20]};
			SType  : imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
			BType  : imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
			JType  : imm_ext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
		endcase
	end

	//Instantiate ALU Decoder module

	ALUdecoder instanceALUDec(

		.funct3(funct3),
		.funct7(funct7),
		.alu_op(ALUOp),
		.alu_control(ALUControl)

	);

	//instantiate Register File module
	registerFile instanceRegFile(

		.Addr1(rs1),
		.Addr2(rs2),
		.Addr3(rd),
		.clk(clk),
		.regWrite(RegWrite),
		.dataIn(ResultData),
		.baseAddr(baseAddr),
		.writeData(writeData)

	);

endmodule
