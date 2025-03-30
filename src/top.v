module InstructionDecoder(

    output [6:0]  op,     
    output [2:0]  funct3, 
    output [6:0]  funct7, 
    output [4:0]  rs1, 
    output [4:0] rs2.
    output [4:0] rd, 
    output [24:0] extend,
    input [31:0] instr

);

assign op = instr[6:0];
assign rd = instr[11:7];
assign funct3 = instr[14:12];
assign rs1 = instr[19:15];
assign rs2 = instr[24:20];
assign funct7 = instr[31:25];
assign extend = instr[31:7];


InstructionDecoder instance1 (

    .instr(instr),
    .rd(rd),
    .funct3(funct3),
    .rs1(rs1),
    .rs2(rs2),
    .funct7(funct7),
    .extend(extend)
);

endmodule