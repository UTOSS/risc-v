`ifndef PARAMS_VH
`define PARAMS_VH

//Opcodes
parameter RType = 7'b0110011;
parameter IType_logic = 7'b0010011;
parameter IType_load = 7'b0000011;
parameter SType = 7'b0100011;
parameter BType = 7'b1100011;
parameter JType = 7'b1101111;

//ALU Operation Control Codes
parameter ALUAdd = 4'b0000;
parameter ALUSub = 4'b0001;
parameter ALUSLL =  4'b0010; 
parameter ALUSLT = 4'b0011;
parameter ALUSLTU = = 4'b0100; 
parameter ALUXOR = 4'b0101;
parameter ALUSRL = 4'b0110; 
parameter ALUSRA = 4'b0111;
parameter ALUOR = 4'b1000;  
parameter ALUAND = 4'b1001;

`endif // PARAMS_VH
