module ALU_Decoder(
	
	input wire [1:0] ALUOp,
	input wire [2:0] funct3,
	input wire opcode5,
	input wire funct7_5,
	output reg [2:0] ALUControl

);
	
	wire opfunct7 = {opcode5, funct7_5};

	always@(*) begin
	
		if (ALUOp == 2'b00) ALUControl = 3'b000;
		
		else if (ALUOp == 2'b01) ALUControl = 3'b001;
		
		else if (ALUOp == 2'b10) begin
		
			case (funct3)
			
				3'b000: begin
				
					if (opfunct7 == 2'b00 || opfunct7 == 2'b01 || opfunct7 == 2'b10) 
						ALUControl = 3'b000;
					
					else ALUControl = 3'b001;
				
				end
				
				3'b010: ALUControl = 3'b101;
				
				3'b110: ALUControl = 3'b011;
				
				3'b111: ALUControl = 3'b010;
				
				default: ALUControl  = 3'b000;
			
			endcase
		
		end
		
		else ALUControl = 3'b000;
	
	end

endmodule