`timescale 1ns/1ps

`include "src/utils.svh"
`include "src/types.svh"

`include "test/utils.svh"

module fetch_tb;

  reg     clk;
  reg     reset;
  reg     cfsm__pc_write;
  reg     cfsm__ir_write;
  addr_t  result;
  addr_t  pc_cur;
  addr_t  pc_old;

  fetch uut
    ( .clk             ( clk            )
    , .reset           ( reset          )
    , .cfsm__pc_write  ( cfsm__pc_write )
    , .cfsm__ir_write  ( cfsm__ir_write )
    , .result          ( result         )

    // outputs
    , .pc_cur          ( pc_cur         )
    , .pc_old          ( pc_old         )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin

    // testing incrementing pc naturally
    cfsm__pc_write <= `FALSE;
    cfsm__ir_write <= `FALSE;

    assert(pc_cur  === 32'hxxxxxxxx) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    reset <= `TRUE;

    @(posedge clk); #1;

    assert(pc_cur  === 32'h00000000) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);
    assert(pc_old  === 32'hxxxxxxxx) else $fatal(1,"`pc_old` is `%0h`", pc_old);

    reset <= `FALSE;

    @(posedge clk); #1;

    assert(pc_cur  === 32'h00000000) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    cfsm__ir_write <= `TRUE;

    @(posedge clk); #1;

    assert(pc_old  === 32'h00000000) else $fatal(1,"`pc_old` is `%0h`", pc_old);

    // pc incremented
    result <= 32'h00000004;
    cfsm__pc_write <= `TRUE;
    cfsm__ir_write <= `FALSE;

    @(posedge clk); #1;

    assert(pc_cur  === 32'h00000004) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);
    assert(pc_old  === 32'h00000000) else $fatal(1,"`pc_old` is `%0h`", pc_old);

    cfsm__ir_write <= `TRUE;

    @(posedge clk); #1;
    assert(pc_cur  === 32'h00000004) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);
    assert(pc_old  === 32'h00000004) else $fatal(1,"`pc_old` is `%0h`", pc_old);

    // pc jumped
    result <= 32'h0000beef;
    cfsm__pc_write <= `TRUE;
    cfsm__ir_write <= `FALSE;

    @(posedge clk); #1;
    assert(pc_cur  === 32'h0000beef) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);
    assert(pc_old  === 32'h00000004) else $fatal(1,"`pc_old` is `%0h`", pc_old);

    $finish;
  end

  `SETUP_VCD_DUMP(fetch_tb)

endmodule
