`timescale 1ns/1ps

`include "test/utils.svh"

module lui_tb;

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

    uut.memory.M[0] = 32'h123450b7; // lui a0, 0x12345
    uut.memory.M[1] = 32'h7d5c0837; // lui a6, 0x7d5c0

    uut.instruction_decode.instanceRegFile.RFMem[ 1] = 32'hffffffff; // x1
    uut.instruction_decode.instanceRegFile.RFMem[16] = 32'hffffffff; // a6

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    `assert_equal(uut.opcode, 7'b0110111)
    `assert_equal(uut.instruction_decode.rd, 1) // x1
    `assert_equal(uut.instruction_decode.imm_ext, 32'h12345000)

    wait_till_next_cfsm_state(uut.control_fsm.EXECUTEI);

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    `assert_equal(uut.alu_out, 32'h12345000)
    `assert_equal(uut.result, 32'h12345000)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[ 1], 32'h12345000) // x1
    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[16], 32'hffffffff) // a6

    `assert_equal(uut.fetch.pc_cur, 4) // starting second instruction already

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    `assert_equal(uut.opcode, 7'b0110111)
    `assert_equal(uut.instruction_decode.rd, 16) // a6
    `assert_equal(uut.instruction_decode.imm_ext, 32'h7d5c0000)

    wait_till_next_cfsm_state(uut.control_fsm.EXECUTEI);

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    `assert_equal(uut.alu_out, 32'h7d5c0000)
    `assert_equal(uut.result, 32'h7d5c0000)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[ 1], 32'h12345000) // x1
    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[16], 32'h7d5c0000) // a6
    `assert_equal(uut.fetch.pc_cur, 8) // starting third instruction already

    $finish;
  end

  `SETUP_VCD_DUMP(lui_tb)

endmodule
