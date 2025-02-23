`include "params.vh"

module ALUdecoder_new (input [2:0] funct3, input [6:0] funct7, reg output alu_op);
	always @(*)
	begin
	case (funct3)
		3'b000: 
			if (funct7==7'h00) alu_op = ALUAdd;      //ADD
			else if (funct7==7'h20) alu_op = ALUSub; //SUB
		3'b001: alu_op = ALUSLL;                         //SLL
		3'b010: alu_op = ALUSLT;                         //SLT
		3'b011: alu_op = ALUSLTU;                         //SLTU
		3'b100: alu_op = ALUXOR;			//XOR
		3'b101: 
			if (funct7==7'h00) alu_op = ALUSRL;      //SRL
			else if (funct7==7'h20) alu_op = ALUSRA; //SRA
		3'b110: alu_op = ALUOR;                         //OR
		3'b111: alu_op = ALUAND;                         //AND
		default: alu_op = 4'b0;
	endcase
endmodule
