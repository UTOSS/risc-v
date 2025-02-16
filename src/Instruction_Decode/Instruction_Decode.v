`include "params.vh"
module Instruction_Decode( 

	input wire [31:0] instr,
	input wire clk,
	input wire reset,
	input wire [31:0] ResultData,
	output wire AdrSrc,
	output wire IRWrite,
	//output wire RegWrite,
	output wire PCUpdate,
	output wire MemWrite,
	output wire Branch,
	output wire [1:0] ALUSrcA,
	output wire [1:0] ALUSrcB,
	output wire [1:0] ResultSrc,
	output wire [2:0] ALUControl,
	output wire [31:0] baseAddr,
	output wire [31:0] writeData
									  
);

	reg [31:0] ImmExt;
	wire [2:0] ALUOp; //wire from Control FSM to ALU Decoder
	wire RegWrite;
	reg [2:0] funct3;
	reg [6:0] funct7
	reg [4:0] rd, rs1, rs2;
	wire [3:0] state;
	
	//combinational logic for extracting funct3 and funct7[5] for ALU Decoder input
	always@(*) begin
	
		if (instr[6:0] == RType) begin //R-Type
		
			funct3 = instr[14:12];
			funct7 = instr[31:25];
		
		end
		
		else if (instr[6:0] == IType) begin  //I-Type (excluding lw)
		
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
	
		if (instr[6:0] == RType) begin //R-Type
		
			rd = instr[11:7];
			rs1 = instr[19:15];
			rs2 = instr[24:20];
		
		end
		
		else if (instr[6:0] == IType || instr[6:0] == LWType) begin //I-Type (where lw is I type)
		
			rd = instr[11:7];
			rs1 = instr[19:15];
			rs2 = 5'b00000;
		
		end
		
		else if (instr[6:0] == SType || instr[6:0] == BType) begin //S-type and B-Type
		
			rd = 5'b00000;
			rs1 = instr[19:15];
			rs2 = instr[24:20];
		
		end
		
		else if (instr[6:0] == JType) begin //J-Type
		
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
																
	//case statement for choosing 32-bit immediate format; based on opcode
	always@(*) begin
		case(instr[6:0]) 

			7'b0010011: ImmExt = {{20{instr[31]}}, instr[31:20]}; //I-Type
			7'b0000011: ImmExt = {{20{instr[31]}}, instr[31:20]}; //lw
			7'b0100011: ImmExt = {{20{instr[31]}}, instr[31:25], instr[11:7]}; //S-Type
			7'b1100011: ImmExt = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; //B-Type
			7'b1101111: ImmExt = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; //J-Type

		endcase
	end

	//instantiate state machine module
	ControlFSM instanceFSM(
		
		.opcode(instr[6:0]),
		.clk(clk),
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
		.FSMState(state)
	
	);

	//Instantiate ALU Decoder module
	
	ALUdecoder instanceALUDec(
	
		.funct3(funct3),
		.funct7(funct7),
		.alu_op(ALUControl)
	
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
