`timescale 1ns/1ps

`include "src/utils.svh"
`include "src/types.svh"

module beq_tb;
  reg clk;
  reg reset;

  top uut
    ( .clk(clk)
    , .reset(reset)
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin

    // initialize instruction memory
    reset <= `TRUE;

    // initialize memory
    uut.fetch.instruction_memory.M[0] = 32'hFE420AE3; // beq x4, x4, -0xc

    #10;
    reset <= `FALSE;

    assert(uut.fetch.pc_cur  == 32'h00000000) else $error("`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);
    assert(uut.fetch.imm_ext == 32'hFFFFFFF4) else $error("`uut.fetch.imm_ext` is `%0h`", uut.fetch.imm_ext);
    assert(uut.opcode       ==  7'b1100011)  else $error("`uut.opcode` is `%0b`", uut.opcode);

    #10

    assert(uut.fetch.pc_cur  == 32'h00000000) else $error("`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

    $finish;
  end

  initial begin
    $dumpfile("test/beq_tb.vcd");
    $dumpvars(0, beq_tb);
  end
endmodule
