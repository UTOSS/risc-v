`timescale 1ns/1ns

module zba_tb;

reg[31:0] reg1;
reg[31:0] reg2;
reg[1:0] inst;
wire[31:0] out;

zba uut(
    .reg1(reg1), 
    .reg2(reg2), 
    .inst(inst), 
    .out(out));

initial begin

    $dumpfile("zba.vcd");
    $dumpvars(0, zba_tb);

    reg1 = 32'd10; reg2 = 31'd5; inst=2'b00; #20;
    reg1 = 32'd10; reg2 = 31'd5; inst=2'b01; #20;
    reg1 = 32'd10; reg2 = 31'd5; inst=2'b10; #20;

    $finish;

end

endmodule