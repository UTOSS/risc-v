`timescale 1ns/1ps

`include "test/utils.svh"

module sw_tb;

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

    // set up instructions and data memory
    uut.memory.M[ 0] = 32'h00532023; // sw x5, 0(x6)
    uut.memory.M[ 4] = 32'h00532223; // sw x5, 4(x6)
    uut.memory.M[ 8] = 32'h00532423; // sw x5, 8(x6)
    uut.memory.M[34] = 32'hbadab00f; // initial value
    uut.memory.M[42] = 32'hdeadbeef; // initial value
    uut.memory.M[46] = 32'hcafebabe; // initial value
    uut.memory.M[50] = 32'h00000000; // will be written by sw x5, 8(x6)

    // set up register file
    uut.instruction_decode.instanceRegFile.RFMem[6] = 42;    // x6 = 42
    uut.instruction_decode.instanceRegFile.RFMem[5] = 256;   // x5 = 256

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    reset <= `FALSE;

    // --- Instruction 1: sw x5, 0(x6) ---
    wait_till_next_cfsm_state(uut.control_fsm.DECODE);
    `assert_equal(uut.opcode, 7'b0100011)
    `assert_equal(uut.instruction_decode.rs1, 6)
    `assert_equal(uut.instruction_decode.rs2, 5)
    `assert_equal(uut.instruction_decode.imm_ext, 0)

    wait_till_next_cfsm_state(uut.control_fsm.MEMADR);
    `assert_equal(uut.alu.out, 42)

    wait_till_next_cfsm_state(uut.control_fsm.MEMWRITE);
    `assert_equal(uut.memory_address, 42)
    `assert_equal(uut.memory.M[42], 256)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    `assert_equal(uut.fetch.pc_cur, 4)

    // --- Instruction 2: sw x5, 4(x6) ---
    wait_till_next_cfsm_state(uut.control_fsm.DECODE);
    `assert_equal(uut.instruction_decode.imm_ext, 4)

    wait_till_next_cfsm_state(uut.control_fsm.MEMADR);
    `assert_equal(uut.alu.out, 46)

    wait_till_next_cfsm_state(uut.control_fsm.MEMWRITE);
    `assert_equal(uut.memory.M[46], 256)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    `assert_equal(uut.fetch.pc_cur, 8)

    // --- Instruction 3: sw x5, 8(x6) ---
    wait_till_next_cfsm_state(uut.control_fsm.DECODE);
    `assert_equal(uut.instruction_decode.imm_ext, 8)

    wait_till_next_cfsm_state(uut.control_fsm.MEMADR);
    `assert_equal(uut.alu.out, 50)

    wait_till_next_cfsm_state(uut.control_fsm.MEMWRITE);
    `assert_equal(uut.memory.M[50], 256)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    // Final assertions
    `assert_equal(uut.memory.M[42], 256)
    `assert_equal(uut.memory.M[46], 256)
    `assert_equal(uut.memory.M[50], 256)
    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[5], 256)
    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[6], 42)
  end

  `SETUP_VCD_DUMP(sw_tb)

endmodule
