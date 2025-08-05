`timescale 1ns/1ps

`include "src/utils.svh"
`include "src/types.svh"

`include "test/utils.svh"

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

  task wait_till_next_cfsm_state(input [5:0] expected_state);
    @(posedge clk); #1;
    `assert_equal(uut.control_fsm.current_state, expected_state)
  endtask

  initial begin

    // initialize instruction memory
    reset <= `TRUE;

    // initialize memory
    uut.memory.M[0] = 32'h00420663; // beq x4, x4, -0xc
    uut.memory.M[3] = 32'h00108093; // addi x1, x1, 1 ; dummy instruction

    // initialize registers
    uut.instruction_decode.instanceRegFile.RFMem[5'b00100] = 32'h0000002a; // x4 = 42

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    reset <= `FALSE;

    assert(uut.alu.a == 32'h00000000) else $fatal(1,"`uut.alu.a` is `%0h`", uut.alu.a); // old pc
    assert(uut.alu.b == 32'h00000004) else $fatal(1,"`uut.alu.b` is `%0h`", uut.alu.b);
    assert(uut.alu.out == 32'h00000004) else $fatal(1,"`uut.alu.out` is `%0h`", uut.alu.out);

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    assert(uut.opcode ==  7'b1100011) else $fatal(1,"`uut.opcode` is `%0b`", uut.opcode);

    assert(uut.fetch.pc_cur  == 32'h00000004) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

    assert(uut.alu.a == 32'h00000000) else $fatal(1,"`uut.alu.a` is `%0h`", uut.alu.a); // old pc
    assert(uut.alu.b == 32'h0000000c) else $fatal(1,"`uut.alu.b` is `%0h`", uut.alu.b); // imm_ext

    wait_till_next_cfsm_state(uut.control_fsm.BRANCHIFEQ);

    assert(uut.rd1 == 32'h0000002a) else $fatal(1,"`uut.rd1` is `%0h`", uut.rd1);
    assert(uut.rd2 == 32'h0000002a) else $fatal(1,"`uut.rd2` is `%0h`", uut.rd2);

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    assert(uut.dataA == 32'h0000002a) else $fatal(1,"`uut.dataA` is `%0h`", uut.dataA);
    assert(uut.dataB == 32'h0000002a) else $fatal(1,"`uut.dataB` is `%0h`", uut.dataB);
    assert(uut.alu__zero_flag == `TRUE)        else $fatal(1,"`uut.alu__zero_flag` is `%0b`", uut.alu__zero_flag);

    assert(uut.alu.a == 32'h0000002a) else $fatal(1,"`uut.alu.a` is `%0h`", uut.alu.a);
    assert(uut.alu.b == 32'h0000002a) else $fatal(1,"`uut.alu.b` is `%0h`", uut.alu.b);

    // assert(uut.cfsm__pc_src   == 1 /* JUMP */) else $fatal(1,"`uut.cfsm__pc_src` is `%0b`", uut.cfsm__pc_src);

    assert(uut.fetch.pc_cur    == 32'h0000000c) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    assert(uut.fetch.pc_cur    == 32'hFFFFFFF8) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

    // beq without satisfied condition
    @(posedge clk); #1;
    reset <= `TRUE;

    uut.memory.M[0] = 32'b0000000_00010_00001_000_1000_0_1100011; // beq x1, x2, 0x10
    uut.instruction_decode.instanceRegFile.RFMem[5'b00001] = 32'h0000002a; // x1 = 42
    uut.instruction_decode.instanceRegFile.RFMem[5'b00010] = 32'h0000002b; // x2 = 43

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    reset <= `FALSE;

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    assert(uut.opcode ==  7'b1100011) else $fatal(1,"`uut.opcode` is `%0b`", uut.opcode);

    assert(uut.fetch.pc_cur  == 32'h00000004) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);
    // assert(uut.fetch.imm_ext == 32'h00000010) else $fatal(1,"`uut.fetch.imm_ext` is `%0h`", uut.fetch.imm_ext);

    wait_till_next_cfsm_state(uut.control_fsm.BRANCHIFEQ);

    assert(uut.alu.a == 32'h0000002a) else $fatal(1,"`uut.alu.a` is `%0h`", uut.alu.a);
    assert(uut.alu.b == 32'h0000002b) else $fatal(1,"`uut.alu.b` is `%0h`", uut.alu.b);

    assert(uut.alu__zero_flag == `FALSE)     else $fatal(1,"`uut.alu__zero_flag` is `%0b`", uut.alu__zero_flag);

    // assert(uut.cfsm__pc_src   == 0 /* +4 */) else $fatal(1,"`uut.cfsm__pc_src` is `%0b`", uut.cfsm__pc_src);
    assert(uut.fetch.pc_cur    == 32'h00000004) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    assert(uut.fetch.pc_cur    == 32'h00000008) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

    @(posedge clk); #1; // check that zero-setting instructions do not result in a jump
    reset <= `TRUE;

    uut.memory.M[0] = 32'b0100000_00001_00001_000_00001_0110011; // sub x1, x1, x1
    uut.instruction_decode.instanceRegFile.RFMem[5'b00001] = 32'h00000001; // x1 = 1

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    reset <= `FALSE;

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    assert(uut.fetch.pc_cur    == 32'h00000004) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

    wait_till_next_cfsm_state(uut.control_fsm.EXECUTER);

    assert(uut.alu__zero_flag == `TRUE)     else $fatal(1,"`uut.alu__zero_flag` is `%0b`", uut.alu__zero_flag);

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    assert(uut.fetch.pc_cur    == 32'h00000004) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

    $finish;
  end

  `SETUP_VCD_DUMP(beq_tb)

endmodule
