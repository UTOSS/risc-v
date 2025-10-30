`timescale 1ns/1ps

`include "test/utils.svh"

module addi_tb;

  reg clk;
  reg reset;

  utoss_riscv uut
    ( .clk   ( clk   )
    , .reset ( reset )
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
    reset <= `TRUE;

    // Set up instruction memory
    uut.memory.M[ 0] = 32'h00010093; // addi x1, x2, 0
    uut.memory.M[ 1] = 32'h00410093; // addi x1, x2, 4
    uut.memory.M[ 2] = 32'hff810093; // addi x1, x2, -8

    // Set up register file
    uut.RegFile.RFMem[1] = 0; // x1 = 0
    uut.RegFile.RFMem[2] = 42; // x2 = 42

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    reset <= `FALSE;

    // --- Instruction 1: addi x1, x2, 0 ---
    wait_till_next_cfsm_state(uut.control_fsm.DECODE);
    `assert_equal(uut.opcode, 7'b0010011)
    `assert_equal(uut.instruction_decode.rs1, 2)
    `assert_equal(uut.instruction_decode.rd, 1)
    `assert_equal(uut.instruction_decode.imm_ext, 0)

    wait_till_next_cfsm_state(uut.control_fsm.EXECUTEI);
    `assert_equal(uut.alu.a, 42)
    `assert_equal(uut.alu.b, 0)
    `assert_equal(uut.alu.out, 42)

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    `assert_equal(uut.RegFile.RFMem[1], 42)
    `assert_equal(uut.fetch.pc_cur, 4)

    // --- Instruction 2: addi x1, x2, 4 ---
    wait_till_next_cfsm_state(uut.control_fsm.DECODE);
    `assert_equal(uut.instruction_decode.imm_ext, 4)

    wait_till_next_cfsm_state(uut.control_fsm.EXECUTEI);
    `assert_equal(uut.alu.out, 46)

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    `assert_equal(uut.RegFile.RFMem[1], 46)
    `assert_equal(uut.fetch.pc_cur, 8)

    // --- Instruction 3: addi x1, x2, -8 ---
    wait_till_next_cfsm_state(uut.control_fsm.DECODE);
    `assert_equal(uut.instruction_decode.imm_ext, -8)

    wait_till_next_cfsm_state(uut.control_fsm.EXECUTEI);
    `assert_equal(uut.alu.out, 34)

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    `assert_equal(uut.RegFile.RFMem[1], 34)

    // Final assertions
    `assert_equal(uut.RegFile.RFMem[2], 42)
    `assert_equal(uut.RegFile.RFMem[1], 34)

    $finish;
  end

  `SETUP_VCD_DUMP(addi_tb)

endmodule
