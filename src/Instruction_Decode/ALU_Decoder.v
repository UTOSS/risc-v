`include "params.vh"

module ALUdecoder (input [2:0] funct3, input [6:0] funct7, input [1:0] alu_op, reg output [3:0] alu_control);
	always @(*)
	begin
	case (alu_op)
		2'b00: alu_control = 4'b0000; //lw, sw (ADD)
		2'b01: alu_control = 4'b0001; //branch (SUB)
		2'b10: //R type
		begin
			case (funct3)
			3'b000: if (funct7==7'h00) alu_control = 4'b0000;      //ADD
				else if (funct7==7'h20) alu_control = 4'b0001; //SUB
			3'b001: alu_control = 4'b0010;                         //SLL
			3'b010: alu_control = 4'b0011;                         //SLT
			3'b011: alu_control = 4'b0100;                         //SLTU
			3'b100: alu_control = 4'b0101;						  //XOR
			3'b101: if (funct7==7'h00) alu_control = 4'b0110;      //SRL
				else if (funct7==7'h20) alu_control = 4'b0111; //SRA
			3'b110: alu_control = 4'b1000;                         //OR
			3'b111: alu_control = 4'b1001;                         //AND
			default: alu_control = 4'b0;
			endcase
		end
		2'b11: //I type
		begin
			case (funct3)
			3'b000: alu_control = 4'b0000;      					//ADDI
			3'b001: alu_control = 4'b0010;                         //SLLI
			3'b010: alu_control = 4'b0011;                         //SLTI
			3'b011: alu_control = 4'b0100;                         //SLTIU
			3'b100: alu_control = 4'b0101;						  //XORI
			3'b101: if (funct7==7'h00) alu_control = 4'b0110;      //SRLI
				else if (funct7==7'h20) alu_control = 4'b0111;    //SRAI
// I type doesn't have funct7; the funct7 here is the upper 7 bits of the immediate
			3'b110: alu_control = 4'b1000;                         //ORI
			3'b111: alu_control = 4'b1001;                         //ANDI
			default: alu_control = 4'b0;
			endcase
		end
	endcase
	end
endmodule
