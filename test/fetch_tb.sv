`timescale 1ns/1ps

`include "src/utils.svh"
`include "src/types.svh"

module fetch_tb;

  reg     clk;
  reg     reset;
  reg     cfsm__pc_update;
  reg     cfsm__pc_src;
  imm_t   imm_ext;
  instr_t instr;

  fetch uut
    ( .clk             ( clk             )
    , .reset           ( reset           )
    , .cfsm__pc_update ( cfsm__pc_update )
    , .cfsm__pc_src    ( cfsm__pc_src    )
    , .imm_ext         ( imm_ext         )
    , .instr           ( instr           )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin

    // testing incrementing pc naturally
    cfsm__pc_update <= `FALSE;
    cfsm__pc_src    <= 1;

    assert(uut.pc_cur  === 32'hxxxxxxxx) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'hxxxxxxxx) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hxxxxxxxx) else $error("`instr` is `%0h`", instr);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    // pc is set at the start
    assert(uut.pc_cur  === 32'h00000000) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000004) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    // instruction is unknown since memory is not initialized
    assert(instr       === 32'hxxxxxxxx) else $error("`instr` is `%0h`", instr);

    #10;

    // pc_cur has not changed since we need pc_update to be set
    assert(uut.pc_cur  === 32'h00000000) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000004) else $error("`uut.pc_next` is `%0h`", uut.pc_next);

    cfsm__pc_update <= `TRUE;

    #10;

    // pc_cur is updated
    assert(uut.pc_cur  === 32'h00000004) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    // pc_next is incremented
    assert(uut.pc_next === 32'h00000008) else $error("`uut.pc_next` is `%0h`", uut.pc_next);

    cfsm__pc_update <= `FALSE;

    #10;

    // pc_cur and pc_next are the same
    assert(uut.pc_cur  === 32'h00000004) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000008) else $error("`uut.pc_next` is `%0h`", uut.pc_next);

    // initialize memory
    uut.instruction_memory.M[0] = 32'h11223344;
    uut.instruction_memory.M[1] = 32'h55667788;
    uut.instruction_memory.M[2] = 32'h99aabbcc;
    uut.instruction_memory.M[3] = 32'hddeeff00;

    for (int i = 4; i < 1020; i = i + 1) begin
      uut.instruction_memory.M[i] = 32'h00000000;
    end

    uut.instruction_memory.M[1020] = 32'hdeadbeef;
    uut.instruction_memory.M[1021] = 32'hfeedface;
    uut.instruction_memory.M[1022] = 32'hcafebabe;
    uut.instruction_memory.M[1023] = 32'hf00dcafe;

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    assert(uut.pc_cur  === 32'h00000000) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000004) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'h11223344) else $error("`instr` is `%0h`", instr);

    // request another instruction
    cfsm__pc_update <= `TRUE;
    #10;

    assert(uut.pc_cur  === 32'h00000004) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000008) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'h55667788) else $error("`instr` is `%0h`", instr);

    #10;

    assert(uut.pc_cur  === 32'h00000008) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h0000000c) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'h99aabbcc) else $error("`instr` is `%0h`", instr);

    #10;

    assert(uut.pc_cur  === 32'h0000000c) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000010) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hddeeff00) else $error("`instr` is `%0h`", instr);

    #10170;

    assert(uut.pc_cur  === 32'h00000ff0) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000ff4) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hdeadbeef) else $error("`instr` is `%0h`", instr);

    #10;

    assert(uut.pc_cur  === 32'h00000ff4) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000ff8) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hfeedface) else $error("`instr` is `%0h`", instr);

    #10;

    assert(uut.pc_cur  === 32'h00000ff8) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000ffc) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hcafebabe) else $error("`instr` is `%0h`", instr);

    #10;

    assert(uut.pc_cur  === 32'h00000ffc) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00001000) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hf00dcafe) else $error("`instr` is `%0h`", instr);

    #10;

    // out of memory
    assert(uut.pc_cur  === 32'h00001000) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00001004) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hxxxxxxxx) else $error("`instr` is `%0h`", instr);

    reset <= `TRUE;
    #10;
    reset <= `FALSE;

    // testing pc update via pc_target
    uut.instruction_memory.M[64] = 32'hdeadbeef;
    uut.instruction_memory.M[65] = 32'hfeedface;
    uut.instruction_memory.M[66] = 32'hcafebabe;
    uut.instruction_memory.M[128] = 32'hf00dcafe;
    uut.instruction_memory.M[129] = 32'hd00dfafe;

    cfsm__pc_src <= 0;
    imm_ext      <= 32'h00000100;

    #10;

    assert(uut.pc_cur  === 32'h00000100) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000200) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hdeadbeef) else $error("`instr` is `%0h`", instr);

    #10;

    assert(uut.pc_cur  === 32'h00000200) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000300) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hf00dcafe) else $error("`instr` is `%0h`", instr);

    cfsm__pc_src <= 1;

    #10;

    assert(uut.pc_cur  === 32'h00000204) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00000208) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hd00dfafe) else $error("`instr` is `%0h`", instr);

    imm_ext <= 32'h00002000; // out of memory bounds
    cfsm__pc_src <= 0;

    #10;

    assert(uut.pc_cur  === 32'h00002204) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00004204) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hxxxxxxxx) else $error("`instr` is `%0h`", instr);

    imm_ext <= 32'h0; // zero jump

    #10;

    assert(uut.pc_cur  === 32'h00002204) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00002204) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hxxxxxxxx) else $error("`instr` is `%0h`", instr);

    imm_ext <= -32'd1; // negative jump

    #10;

    assert(uut.pc_cur  === 32'h00002203) else $error("`uut.pc_cur` is `%0h`", uut.pc_cur);
    assert(uut.pc_next === 32'h00002202) else $error("`uut.pc_next` is `%0h`", uut.pc_next);
    assert(instr       === 32'hxxxxxxxx) else $error("`instr` is `%0h`", instr);

    $finish;
  end

  initial begin
    $dumpfile("test/fetch_tb.vcd");
    $dumpvars(0, fetch_tb);
  end
endmodule
