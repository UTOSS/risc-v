module ALUdecoder (input [2:0] funct3, input [6:0] funct7, output reg [3:0] alu_op);
	
	always @(*)
	begin
		case (funct3)
			3'b000:
				if (funct7==7'h00) alu_op = 4'b0000;      //ADD
				else if (funct7==7'h20) alu_op = 4'b0001; //SUB
			3'b001: alu_op = 4'b0010;                         //SLL
			3'b010: alu_op = 4'b0011;                         //SLT
			3'b011: alu_op = 4'b0100;                         //SLTU
			3'b100: alu_op = 4'b0101;						  //XOR
			3'b101:
				if (funct7==7'h00) alu_op = 4'b0110;      //SRL
				else if (funct7==7'h20) alu_op = 4'b0111; //SRA
			3'b110: alu_op = 4'b1000;                         //OR
			3'b111: alu_op = 4'b1001;                         //AND
			default: alu_op = 4'b0;
		endcase
	end
endmodule
