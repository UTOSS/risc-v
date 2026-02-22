`timescale 1ns/1ns
`include "test/utils.svh"

module zba_tb;

reg[31:0] reg1;
reg[31:0] reg2;
reg[1:0] inst;

/* verilator lint_off UNUSEDSIGNAL */
wire[31:0] out;
/* verilator lint_on UNUSEDSIGNAL */

zba uut(.reg1(reg1)
  , .reg2(reg2)
  , .inst(inst)
  , .funct3(3'b000) //these were missing
  , .funct7(7'b0000000)
  , .out(out)
  );

initial begin

    reg1 = 32'd10; reg2 = 32'd5; inst=2'b00; #20;
    reg1 = 32'd10; reg2 = 32'd5; inst=2'b01; #20;
    reg1 = 32'd10; reg2 = 32'd5; inst=2'b10; #20;

    $finish;

end

`SETUP_VCD_DUMP(zba_tb)

endmodule
