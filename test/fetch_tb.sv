`timescale 1ns/1ps

`include "src/utils.svh"
`include "src/types.svh"

`include "test/utils.svh"

module fetch_tb;

  reg     clk;
  reg     reset;
  reg     cfsm__pc_update;
  reg     cfsm__pc_src;
  imm_t   imm_ext;
  addr_t  pc_cur;

  fetch uut
    ( .clk             ( clk             )
    , .reset           ( reset           )
    , .cfsm__pc_update ( cfsm__pc_update )
    , .cfsm__pc_src    ( cfsm__pc_src    )
    , .imm_ext         ( imm_ext         )

    // outputs
    , .pc_cur          ( pc_cur          )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin

    // testing incrementing pc naturally
    cfsm__pc_update <= `FALSE;
    cfsm__pc_src    <= 0;

    assert(pc_cur  === 32'hxxxxxxxx) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    // pc is set at the start
    assert(pc_cur  === 32'h00000000) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10;

    // pc_cur has not changed since we need pc_update to be set
    assert(pc_cur  === 32'h00000000) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    cfsm__pc_update <= `TRUE;

    #10;

    // pc_cur is updated
    assert(pc_cur  === 32'h00000004) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    cfsm__pc_update <= `FALSE;

    #10;

    // pc_cur and pc_next are the same
    assert(pc_cur  === 32'h00000004) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    assert(pc_cur  === 32'h00000000) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    // request another instruction
    cfsm__pc_update <= `TRUE;
    #10; // back to fetch state

    assert(pc_cur  === 32'h00000004) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10;

    assert(pc_cur  === 32'h00000008) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10;

    assert(pc_cur  === 32'h0000000c) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10170;

    assert(pc_cur  === 32'h00000ff0) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10;

    assert(pc_cur  === 32'h00000ff4) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10;

    assert(pc_cur  === 32'h00000ff8) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10;

    assert(pc_cur  === 32'h00000ffc) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10;

    // out of memory
    assert(pc_cur  === 32'h00001000) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    // testing pc update via pc_target
    cfsm__pc_src <= 1;
    imm_ext      <= 32'h00000100;

    #10;

    assert(pc_cur  === 32'h00000100) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    #10;

    assert(pc_cur  === 32'h00000200) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    cfsm__pc_src <= 0;

    #10;

    assert(pc_cur  === 32'h00000204) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    imm_ext <= 32'h00002000; // out of memory bounds
    cfsm__pc_src <= 1;

    #10;

    assert(pc_cur  === 32'h00002204) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    imm_ext <= 32'h0; // zero jump

    #10;

    assert(pc_cur  === 32'h00002204) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    imm_ext <= -32'd1; // negative jump

    #10;

    assert(pc_cur  === 32'h00002203) else $fatal(1,"`pc_cur` is `%0h`", pc_cur);

    $finish;
  end

  `SETUP_VCD_DUMP(fetch_tb)

endmodule
