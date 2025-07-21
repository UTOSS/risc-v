`timescale 1ns/1ps

`include "test/utils.svh"

module lw_tb;

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

    // set up instrctions and data memory
    uut.memory.M[ 0] = 32'h00012083; // lw x1, 0(x2)
    uut.memory.M[42] = 32'hdeadbeef; // have some data at address 42

    // set up register file
    uut.instruction_decode.instanceRegFile.RFMem[2] = 42; // x1 = 42

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    `assert_equal(uut.opcode, 7'b0000011)
    `assert_equal(uut.instruction_decode.rs1, 2)
    `assert_equal(uut.instruction_decode.rs2, 0)
    `assert_equal(uut.instruction_decode.imm_ext, 0)

    wait_till_next_cfsm_state(uut.control_fsm.MEMADR);

    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[2], 42)
    `assert_equal(uut.alu.a, 42)
    `assert_equal(uut.alu.b, 0)
    `assert_equal(uut.alu.out, 42)

    wait_till_next_cfsm_state(uut.control_fsm.MEMREAD);

    `assert_equal(uut.result, 42)
    `assert_equal(uut.memory_address, 42)

    wait_till_next_cfsm_state(uut.control_fsm.MEMWB);

    `assert_equal(uut.data, 32'hdeadbeef)
    `assert_equal(uut.result, 32'hdeadbeef)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[1], 32'hdeadbeef)
    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[2], 42)
    `assert_equal(uut.fetch.pc_cur, 4)

  end

  `SETUP_VCD_DUMP(lw_tb)

endmodule
