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
    `assert_equal(uut.core.control_fsm.current_state, expected_state)
  endtask

  initial begin
    reset <= `TRUE;

    // set up instructions and data memory
    uut.memory.M[ 0] = 32'h00532023; // sw x5, 0(x6)
    uut.memory.M[ 1] = 32'h00532223; // sw x5, 4(x6)
    uut.memory.M[ 2] = 32'h00532423; // sw x5, 8(x6)
    uut.memory.M[10] = 32'hbadab00f; // initial value
    uut.memory.M[11] = 32'hdeadbeef; // initial value
    uut.memory.M[12] = 32'hcafebabe; // initial value
    uut.memory.M[13] = 32'h00000000; // will be written by sw x5, 8(x6)

    // set up register file
    uut.core.RegFile.RFMem[6] = 44;    // x6 = 44
    uut.core.RegFile.RFMem[5] = 256;   // x5 = 256

    wait_till_next_cfsm_state(FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(FETCH_WAIT);

    // --- Instruction 1: sw x5, 0(x6) ---
    wait_till_next_cfsm_state(DECODE);
    `assert_equal(uut.core.opcode, 7'b0100011)
    `assert_equal(uut.core.instruction_decode.rs1, 6)
    `assert_equal(uut.core.instruction_decode.rs2, 5)
    `assert_equal(uut.core.instruction_decode.imm_ext, 0)

    wait_till_next_cfsm_state(MEMADR);
    `assert_equal(uut.core.alu.out, 44)

    wait_till_next_cfsm_state(MEMWRITE);
    `assert_equal(uut.core.memory__address, 44)

    wait_till_next_cfsm_state(FETCH);
    wait_till_next_cfsm_state(FETCH_WAIT);

    `assert_equal(uut.memory.M[11], 256)
    `assert_equal(uut.core.fetch.pc_cur, 4)

    // --- Instruction 2: sw x5, 4(x6) ---
    wait_till_next_cfsm_state(DECODE);

    `assert_equal(uut.core.instruction_decode.imm_ext, 4)

    wait_till_next_cfsm_state(MEMADR);

    `assert_equal(uut.core.alu.out, 48)

    wait_till_next_cfsm_state(MEMWRITE);

    wait_till_next_cfsm_state(FETCH);
    wait_till_next_cfsm_state(FETCH_WAIT);

    `assert_equal(uut.memory.M[12], 256)
    `assert_equal(uut.core.fetch.pc_cur, 8)

    // --- Instruction 3: sw x5, 8(x6) ---
    wait_till_next_cfsm_state(DECODE);

    `assert_equal(uut.core.opcode, 7'b0100011)
    `assert_equal(uut.core.instruction_decode.rs1, 6)
    `assert_equal(uut.core.instruction_decode.rs2, 5)
    `assert_equal(uut.core.instruction_decode.imm_ext, 8)

    wait_till_next_cfsm_state(MEMADR);

    `assert_equal(uut.core.alu.out, 52)

    wait_till_next_cfsm_state(MEMWRITE);

    wait_till_next_cfsm_state(FETCH);
    wait_till_next_cfsm_state(FETCH_WAIT);

    `assert_equal(uut.memory.M[13], 256)

    // Final assertions
    `assert_equal(uut.memory.M[11], 256)
    `assert_equal(uut.memory.M[12], 256)
    `assert_equal(uut.memory.M[13], 256)
    `assert_equal(uut.core.RegFile.RFMem[5], 256)
    `assert_equal(uut.core.RegFile.RFMem[6], 44)

    $finish;
  end

  `SETUP_VCD_DUMP(sw_tb)

endmodule
