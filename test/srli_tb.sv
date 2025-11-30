`timescale 1ns/1ps

`include "test/utils.svh"

module srli_tb;

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
    `assert_equal(uut.core.control_fsm.current_state, expected_state)
  endtask

  initial begin
    reset <= `TRUE;

    // set up instructions and data memory
    uut.memory.M[ 0] = 32'h00115093; // srli x1, x2, 1
    uut.memory.M[ 1] = 32'h00215093; // srli x1, x2, 2
    uut.memory.M[ 2] = 32'h00315093; // srli x1, x2, 3


    // set up register file
    uut.core.RegFile.RFMem[2] = 42; // x2 = 42; 101010

    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(uut.core.control_fsm.DECODE);

    `assert_equal(uut.core.opcode, 7'b0010011)
    `assert_equal(uut.core.instruction_decode.rs1, 2)
    `assert_equal(uut.core.instruction_decode.imm_ext, 32'h1)

    wait_till_next_cfsm_state(uut.core.control_fsm.EXECUTEI);

    `assert_equal(uut.core.RegFile.RFMem[2], 42)
    `assert_equal(uut.core.alu.a, 42)
    `assert_equal(uut.core.alu.b, 1)
    `assert_equal(uut.core.alu.out, 21)

    wait_till_next_cfsm_state(uut.core.control_fsm.ALUWB);

    `assert_equal(uut.core.instruction_decode.rd, 1)

    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);

    `assert_equal(uut.core.RegFile.RFMem[1], 21)
    `assert_equal(uut.core.RegFile.RFMem[2], 42)
    `assert_equal(uut.core.fetch.pc_cur, 4) // starting second instruction already

    wait_till_next_cfsm_state(uut.core.control_fsm.DECODE);

    `assert_equal(uut.core.opcode, 7'b0010011)
    `assert_equal(uut.core.instruction_decode.rs1, 2)
    `assert_equal(uut.core.instruction_decode.imm_ext, 32'h2)

    wait_till_next_cfsm_state(uut.core.control_fsm.EXECUTEI);

    `assert_equal(uut.core.RegFile.RFMem[2], 42)
    `assert_equal(uut.core.alu.a, 42)
    `assert_equal(uut.core.alu.b, 2)
    `assert_equal(uut.core.alu.out, 10)

    wait_till_next_cfsm_state(uut.core.control_fsm.ALUWB);

    `assert_equal(uut.core.instruction_decode.rd, 1)

    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);

    `assert_equal(uut.core.RegFile.RFMem[1], 10)
    `assert_equal(uut.core.RegFile.RFMem[2], 42)
    `assert_equal(uut.core.fetch.pc_cur, 8) // starting third instruction already

    wait_till_next_cfsm_state(uut.core.control_fsm.DECODE);

    `assert_equal(uut.core.opcode, 7'b0010011)
    `assert_equal(uut.core.instruction_decode.rs1, 2)
    `assert_equal(uut.core.instruction_decode.imm_ext, 32'h3)

    wait_till_next_cfsm_state(uut.core.control_fsm.EXECUTEI);

    `assert_equal(uut.core.RegFile.RFMem[2], 42)
    `assert_equal(uut.core.alu.a, 42)
    `assert_equal(uut.core.alu.b, 3)
    `assert_equal(uut.core.alu.out, 5)

    wait_till_next_cfsm_state(uut.core.control_fsm.ALUWB);

    `assert_equal(uut.core.instruction_decode.rd, 1)

    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);

    `assert_equal(uut.core.RegFile.RFMem[1], 5)
    `assert_equal(uut.core.RegFile.RFMem[2], 42)
    `assert_equal(uut.core.fetch.pc_cur, 12)

    $finish;
  end

  `SETUP_VCD_DUMP(srli_tb)

endmodule
