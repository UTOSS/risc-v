`timescale 1ns/1ns
`include "test/utils.svh"

module zba_tb;

reg[31:0] reg1;
reg[31:0] reg2;
reg[2:0] funct3;
reg[6:0] funct7;
wire[31:0] out;

zba uut(.reg1(reg1)
  , .reg2(reg2)
  , .funct3(funct3)
  , .funct7(funct7)
  , .out(out)
  );

initial begin

    reg1 = 32'd10; reg2 = 31'd5; funct3=3'b010; funct7=7'b0000000; #20;
    reg1 = 32'd10; reg2 = 31'd5; funct3=3'b100; funct7=7'b0000000; #20;
    reg1 = 32'd10; reg2 = 31'd5; funct3=3'b110; funct7=7'b0000000; #20;

    $finish;

end

`SETUP_VCD_DUMP(zba_tb)

endmodule