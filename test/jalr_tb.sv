`timescale 1ns/1ps

`include "src/types.svh"  // for enum literals like PC_SRC__ALU_RESULT
`include "test/utils.svh"

module jalr_only_tb;

  reg clk;
  reg reset;

  // DUT
  top uut
    ( .clk   ( clk   )
    , .reset ( reset )
    );

  // 10ns clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // helper: wait to next FSM state and assert it
  task wait_till_next_cfsm_state(input [3:0] expected_state);
    @(posedge clk); #1;
    `assert_equal(uut.core.control_fsm.current_state, expected_state)
  endtask

  // --- Test 1: JALR x1, x2, +5 (rs1=100) -> target=(100+5)&~1 = 104; link=4 ---
  initial begin
    // Hold reset
    reset <= `TRUE;

    // Program @0x00000000:
    //   JALR x1, x2, +5
    // Encoding (I/JALR): imm[11:0] | rs1=2 | funct3=000 | rd=1 | opcode=0x67
    // imm=5 (0x005) -> 0x005100E7
    uut.memory.M[0] = 32'h005100E7;

    // Registers
    uut.core.RegFile.RFMem[1] = 32'd0;    // x1 (link) cleared
    uut.core.RegFile.RFMem[2] = 32'd100;  // x2 = 100

    // Enter FETCH with reset asserted (for stable pc_old=0)
    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);

    // Release reset
    reset <= `FALSE;

    // DECODE: opcode/rs1/rd/imm must match
    wait_till_next_cfsm_state(uut.core.control_fsm.DECODE);
    `assert_equal(uut.core.opcode, 7'b1100111)                  // JALR opcode
    `assert_equal(uut.core.instruction_decode.rs1, 5'd2)        // rs1 = x2
    `assert_equal(uut.core.instruction_decode.rd,  5'd1)        // rd  = x1
    `assert_equal(uut.core.instruction_decode.imm_ext, 32'sd5)  // imm = +5

    // JALR_CALC: ALU computes (rs1+imm) = 105
    wait_till_next_cfsm_state(uut.core.control_fsm.JALR_CALC);
    `assert_equal(uut.core.alu.a, 32'd100)
    `assert_equal(uut.core.alu.b, 32'd5)
    `assert_equal(uut.core.alu.out, 32'd105)

    // JALR_STEP2: PC updates from previous ALU result (with LSB cleared);
    //             ALU computes link = pc_old + 4 (pc_old=0 here)
    wait_till_next_cfsm_state(uut.core.control_fsm.JALR_STEP2);
    `assert_equal(uut.core.cfsm__pc_update, 1'b1)
    `assert_equal(uut.core.cfsm__pc_src, PC_SRC__ALU_RESULT)
    `assert_equal(uut.core.alu.a, 32'd0)     // link base = pc_old
    `assert_equal(uut.core.alu.b, 32'd4)
    `assert_equal(uut.core.alu.out, 32'd4)   // link value

    // ALUWB: write link (4) into rd (x1)
    wait_till_next_cfsm_state(uut.core.control_fsm.ALUWB);

    // Back to FETCH: PC should be (100+5)&~1 = 104, x1 should be 4
    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);
    `assert_equal(uut.core.RegFile.RFMem[1], 32'd4)
    `assert_equal(uut.core.fetch.pc_cur, 32'd104)

    // End of first subtest -> now run a second variant with negative odd imm
    // to further exercise LSB clearing and sign extension.
    @(posedge clk); #1;

    // --- Test 2: JALR x1, x2, -7 (rs1=200) -> target=(200-7)&~1 = 192; link=4 ---
    reset <= `TRUE;

    // Overwrite program @0x00000000:
    //   JALR x1, x2, -7
    // imm = -7 -> 12-bit two's complement 0xFF9
    // encoding -> 0xFF9100E7
    uut.memory.M[0] = 32'hFF9100E7;

    // Registers
    uut.core.RegFile.RFMem[1] = 32'd0;     // x1 cleared
    uut.core.RegFile.RFMem[2] = 32'd200;   // x2 = 200

    // Re-enter FETCH, then release reset
    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);
    reset <= `FALSE;

    // DECODE checks
    wait_till_next_cfsm_state(uut.core.control_fsm.DECODE);
    `assert_equal(uut.core.opcode, 7'b1100111)
    `assert_equal(uut.core.instruction_decode.rs1, 5'd2)
    `assert_equal(uut.core.instruction_decode.rd,  5'd1)
    `assert_equal(uut.core.instruction_decode.imm_ext, -32'sd7)

    // JALR_CALC: 200 + (-7) = 193
    wait_till_next_cfsm_state(uut.core.control_fsm.JALR_CALC);
    `assert_equal(uut.core.alu.a, 32'd200)
    `assert_equal(uut.core.alu.b, -32'sd7)
    `assert_equal(uut.core.alu.out, 32'd193)

    // JALR_STEP2: PC from ALU_RESULT (193 & ~1 = 192); link = pc_old + 4 = 4
    wait_till_next_cfsm_state(uut.core.control_fsm.JALR_STEP2);
    `assert_equal(uut.core.cfsm__pc_update, 1'b1)
    `assert_equal(uut.core.cfsm__pc_src, PC_SRC__ALU_RESULT)
    `assert_equal(uut.core.alu.a, 32'd0)
    `assert_equal(uut.core.alu.b, 32'd4)
    `assert_equal(uut.core.alu.out, 32'd4)

    // Writeback then check PC/link
    wait_till_next_cfsm_state(uut.core.control_fsm.ALUWB);
    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);
    `assert_equal(uut.core.RegFile.RFMem[1], 32'd4)
    `assert_equal(uut.core.fetch.pc_cur, 32'd192)

    $finish;
  end

  `SETUP_VCD_DUMP(jalr_only_tb)

endmodule
