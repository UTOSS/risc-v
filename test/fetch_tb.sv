`timescale 1ns/1ps

`include "src/utils.svh"
`include "src/types.svh"

`include "test/utils.svh"

module fetch_tb;

  reg     clk;
  reg     reset;
  reg     cfsm__pc_update;
  reg [1:0] cfsm__pc_src;
  reg     cfsm__ir_write;
  imm_t   imm_ext;
  addr_t  pc_cur;
  addr_t  pc_old;
  reg [31:0] alu_result_for_pc;

  fetch uut
    ( .clk               ( clk               )
    , .reset             ( reset             )
    , .cfsm__pc_update   ( cfsm__pc_update   )
    , .cfsm__pc_src      ( cfsm__pc_src      )
    , .cfsm__ir_write    ( cfsm__ir_write    )
    , .alu_result_for_pc ( alu_result_for_pc )
    , .imm_ext           ( imm_ext           )

    // outputs
    , .pc_cur            ( pc_cur            )
    , .pc_old            ( pc_old            )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin

    // testing incrementing pc naturally
    cfsm__pc_update <= `FALSE;
    cfsm__pc_src    <= 2'b00;
    cfsm__ir_write  <= 1'b0;
    alu_result_for_pc <= 32'h00000000;
    imm_ext <= '0;

    assert (pc_cur === 32'hxxxxxxxx) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    // pc is set at the start
    assert (pc_cur === 32'h00000000) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    #10;

    // pc_cur has not changed since we need pc_update to be set
    assert (pc_cur === 32'h00000000) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    cfsm__pc_update <= `TRUE;

    #10;

    // pc_cur is updated
    assert (pc_cur === 32'h00000004) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    cfsm__pc_update <= `FALSE;

    #10;

    // pc_cur and pc_next are the same
    assert (pc_cur === 32'h00000004) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    assert (pc_cur === 32'h00000000) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    // request another instruction
    cfsm__pc_update <= `TRUE;
    #10; // back to fetch state

    assert (pc_cur === 32'h00000004) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    #10;

    assert (pc_cur === 32'h00000008) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    #10;

    assert (pc_cur === 32'h0000000c) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    #10170;

    assert (pc_cur === 32'h00000ff0) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    #10;

    assert (pc_cur === 32'h00000ff4) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    #10;

    assert (pc_cur === 32'h00000ff8) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    #10;

    assert (pc_cur === 32'h00000ffc) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    #10;

    // out of memory
    assert (pc_cur === 32'h00001000) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    // testing pc update via pc_target
    cfsm__pc_update <= `TRUE;
    cfsm__pc_src <= 2'b01;
    imm_ext      <= 32'h00000100;

    cfsm__ir_write <= 1'b1;
    #10;
    cfsm__ir_write <= 1'b0;

    #10;

    assert (pc_cur === 32'h00000100) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    // latch new pc_old from current pc before next jump
    cfsm__ir_write <= 1'b1;
    #10;
    cfsm__ir_write <= 1'b0;

    #10;

    assert (pc_cur === 32'h00000200) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    cfsm__pc_src <= 2'b00;

    #10;

    assert (pc_cur === 32'h00000204) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    imm_ext <= 32'h00002000; // out of memory bounds
    cfsm__pc_src <= 2'b01;

    // refresh pc_old so jump uses current pc
    cfsm__ir_write <= 1'b1;
    #10;
    cfsm__ir_write <= 1'b0;

    #10;

    assert (pc_cur === 32'h00002204) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    imm_ext <= 32'h0; // zero jump
    // refresh pc_old so zero jump keeps pc
    cfsm__ir_write <= 1'b1;
    #10;
    cfsm__ir_write <= 1'b0;

    #10;

    assert (pc_cur === 32'h00002204) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    imm_ext <= -32'd1; // negative jump
    // refresh pc_old to current before applying -1
    cfsm__ir_write <= 1'b1;
    #10;
    cfsm__ir_write <= 1'b0;

    #10;

    assert (pc_cur === 32'h00002203) else $fatal(1, "`pc_cur` is `%0h`", pc_cur);

    $finish;
  end

  `SETUP_VCD_DUMP(fetch_tb)

endmodule
