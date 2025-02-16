`timescale 1ns/1ps

`include "src/utils.svh"

module fetch_tb;

  reg      clk;
  reg      reset;
  reg      cfsm__pc_update;
  instr_t  instr;

  fetch uut
    ( .clk             ( clk             )
    , .reset           ( reset           )
    , .cfsm__pc_update ( cfsm__pc_update )
    , .instr           ( instr           )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    cfsm__pc_update <= `FALSE;

    assert(uut.pc_cur  === 32'hxxxxxxxx) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'hxxxxxxxx) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hxxxxxxxx) else $error("`instr` is `%0h`", instr);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    assert(uut.pc_cur  === 32'h00000000) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);

    // need another clock cycle to update `pc_next`
    assert(uut.pc_next === 32'h0000000x) else $error("`uut.pc_next` is `%0h`", uut.pc_next);

    // 
    assert(instr       === 32'h00000000) else $error("`instr` is `%0h`", instr);


    #100;
    $finish;
  end

  initial begin
    $dumpfile("fetch_tb.vcd");
    $dumpvars(0, fetch_tb);
  end
endmodule
