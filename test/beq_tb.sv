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

    // initialize registers
    uut.instruction_decode.instanceRegFile.RFMem[5'b00100] = 32'h0000002a; // x4 = 42

    #10;
    reset <= `FALSE;

    assert(uut.opcode ==  7'b1100011) else $error("`uut.opcode` is `%0b`", uut.opcode);

    assert(uut.fetch.pc_cur  == 32'h00000000) else $error("`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);
    assert(uut.fetch.imm_ext == 32'hFFFFFFF4) else $error("`uut.fetch.imm_ext` is `%0h`", uut.fetch.imm_ext);

    #10 // wait for register retrieval

    assert(uut.alu.a == 32'h0000002a) else $error("`uut.alu.a` is `%0h`", uut.alu.a);
    assert(uut.alu.b == 32'h0000002a) else $error("`uut.alu.b` is `%0h`", uut.alu.b);

    assert(uut.alu__zero_flag == `TRUE)        else $error("`uut.alu__zero_flag` is `%0b`", uut.alu__zero_flag);
    assert(uut.cfsm__pc_src   == 1 /* JUMP */) else $error("`uut.cfsm__pc_src` is `%0b`", uut.cfsm__pc_src);

    assert(uut.fetch.pc_cur    == 32'h00000000) else $error("`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);
    assert(uut.fetch.pc_target == 32'hFFFFFFF4) else $error("`uut.fetch.pc_target` is `%0h`", uut.fetch.pc_target);

    $finish;
  end

  initial begin
    $dumpfile("test/beq_tb.vcd");
    $dumpvars(0, beq_tb);
  end
endmodule
