`timescale 1ns/1ps

`include "test/utils.svh"

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
    `assert_equal(uut.control_fsm.current_state, expected_state)
  endtask

  initial begin
    reset <= `TRUE;

    uut.memory.M[0] = 32'h003160b3; // or x1,x2,x3; x1 = x2 | x3

    uut.RegFile.RFMem[2] = 32'hf0f0f0f0; // x2
    uut.RegFile.RFMem[3] = 32'h0b0b0b0b; // x3

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    `assert_equal(uut.opcode, 7'b0110011)
    `assert_equal(uut.instruction_decode.rd, 1)
    `assert_equal(uut.instruction_decode.rs1, 2)
    `assert_equal(uut.instruction_decode.rs2, 3)
    `assert_equal(uut.instruction_decode.ALUControl, 4'b1000)

    wait_till_next_cfsm_state(uut.control_fsm.EXECUTER);

    `assert_equal(uut.alu.a,   32'hf0f0f0f0)
    `assert_equal(uut.alu.b,   32'h0b0b0b0b)
    `assert_equal(uut.alu.out, 32'hfbfbfbfb)

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    `assert_equal(uut.result, 32'hfbfbfbfb)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.RegFile.RFMem[1], 32'hfbfbfbfb)
    `assert_equal(uut.fetch.pc_cur, 4)

    $finish;
  end

  `SETUP_VCD_DUMP(or_tb)

endmodule
