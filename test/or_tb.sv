`timescale 1ns/1ps

`include "test/utils.svh"
`include "src/packages/pkg_control_fsm.svh"

import pkg_control_fsm::*;

module or_tb;

  reg clk;
  reg reset;

  top uut
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

    uut.memory.M[0] = 32'h003160b3; // or x1,x2,x3; x1 = x2 | x3

    uut.core.RegFile.RFMem[2] = 32'hf0f0f0f0; // x2
    uut.core.RegFile.RFMem[3] = 32'h0b0b0b0b; // x3

    wait_till_next_cfsm_state(FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(FETCH_WAIT);

    wait_till_next_cfsm_state(DECODE);

    `assert_equal(uut.core.opcode, 7'b0110011)
    `assert_equal(uut.core.instruction_decode.rd, 1)
    `assert_equal(uut.core.instruction_decode.rs1, 2)
    `assert_equal(uut.core.instruction_decode.rs2, 3)
    `assert_equal(uut.core.instruction_decode.ALUControl, 4'b1000)

    wait_till_next_cfsm_state(EXECUTER);

    `assert_equal(uut.core.alu.a,   32'hf0f0f0f0)
    `assert_equal(uut.core.alu.b,   32'h0b0b0b0b)
    `assert_equal(uut.core.alu.out, 32'hfbfbfbfb)

    wait_till_next_cfsm_state(ALUWB);

    `assert_equal(uut.core.result, 32'hfbfbfbfb)

    wait_till_next_cfsm_state(FETCH);
    wait_till_next_cfsm_state(FETCH_WAIT);

    `assert_equal(uut.core.RegFile.RFMem[1], 32'hfbfbfbfb)
    `assert_equal(uut.core.fetch.pc_cur, 4)

    $finish;
  end

  `SETUP_VCD_DUMP(or_tb)

endmodule
