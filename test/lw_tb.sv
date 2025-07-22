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

    // set up instructions and data memory
    uut.memory.M[ 0] = 32'h00012083; // lw x1, 0(x2)
    uut.memory.M[ 4] = 32'h00412083; // lw x1, 4(x2)
    uut.memory.M[ 8] = 32'hff812083; // lw x1, -8(x2)
    uut.memory.M[34] = 32'hbadab00f; // have some data at address 34
    uut.memory.M[42] = 32'hdeadbeef; // have some data at address 42
    uut.memory.M[46] = 32'hcafebabe; // have some data at address 46

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
    `assert_equal(uut.fetch.pc_cur, 4) // starting second instruction already

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    `assert_equal(uut.opcode, 7'b0000011)
    `assert_equal(uut.instruction_decode.rs1, 2)
    `assert_equal(uut.instruction_decode.rs2, 0)
    `assert_equal(uut.instruction_decode.imm_ext, 4)

    wait_till_next_cfsm_state(uut.control_fsm.MEMADR);

    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[2], 42)
    `assert_equal(uut.alu.a, 42)
    `assert_equal(uut.alu.b, 4)
    `assert_equal(uut.alu.out, 46)

    wait_till_next_cfsm_state(uut.control_fsm.MEMREAD);

    `assert_equal(uut.result, 46)
    `assert_equal(uut.memory_address, 46)

    wait_till_next_cfsm_state(uut.control_fsm.MEMWB);

    `assert_equal(uut.data, 32'hcafebabe)
    `assert_equal(uut.result, 32'hcafebabe)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[1], 32'hcafebabe)
    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[2], 42)
    `assert_equal(uut.fetch.pc_cur, 8) // starting third instruction already

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    `assert_equal(uut.opcode, 7'b0000011)
    `assert_equal(uut.instruction_decode.rs1, 2)
    `assert_equal(uut.instruction_decode.rs2, 0)
    `assert_equal(uut.instruction_decode.imm_ext, -8)

    wait_till_next_cfsm_state(uut.control_fsm.MEMADR);

    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[2], 42)
    `assert_equal(uut.alu.a, 42)
    `assert_equal(uut.alu.b, -8)
    `assert_equal(uut.alu.out, 34)

    wait_till_next_cfsm_state(uut.control_fsm.MEMREAD);

    `assert_equal(uut.result, 34)
    `assert_equal(uut.memory_address, 34)

    wait_till_next_cfsm_state(uut.control_fsm.MEMWB);

    `assert_equal(uut.data, 32'hbadab00f)
    `assert_equal(uut.result, 32'hbadab00f)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[1], 32'hbadab00f)
    `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[2], 42)
    `assert_equal(uut.fetch.pc_cur, 12)

  end

  `SETUP_VCD_DUMP(lw_tb)

endmodule
