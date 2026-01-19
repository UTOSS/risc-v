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
    `assert_equal(uut.core.control_fsm.current_state, expected_state)
  endtask

  initial begin
    reset <= `TRUE;

    // set up instructions and data memory; M array uses word addressing, hence the indices there
    // are 4 times smaller than the actual addresses corresponding to the beginning to the
    // corresponding word
    uut.memory.M[ 0] = 32'h00012083; // lw x1, 0(x2)
    uut.memory.M[ 1] = 32'h00412083; // lw x1, 4(x2)
    uut.memory.M[ 2] = 32'hff812083; // lw x1, -8(x2)
    uut.memory.M[40] = 32'hbadab00f; // have some data at address 0xa0
    uut.memory.M[42] = 32'hdeadbeef; // have some data at address 0xa8
    uut.memory.M[43] = 32'hcafebabe; // have some data at address 0xac

    // set up register file
    uut.core.RegFile.RFMem[2] = 32'ha8; // x2 = 42 * 4 = 168 = 0xa8

    wait_till_next_cfsm_state(FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(FETCH_WAIT);

    wait_till_next_cfsm_state(DECODE);

    `assert_equal(uut.core.opcode, 7'b0000011)
    `assert_equal(uut.core.instruction_decode.rs1, 2)
    `assert_equal(uut.core.instruction_decode.rs2, 0)
    `assert_equal(uut.core.instruction_decode.imm_ext, 0)

    wait_till_next_cfsm_state(MEMADR);

    `assert_equal(uut.core.RegFile.RFMem[2], 32'ha8)
    `assert_equal(uut.core.alu.a, 32'ha8)
    `assert_equal(uut.core.alu.b, 0)
    `assert_equal(uut.core.alu.out, 32'ha8)

    wait_till_next_cfsm_state(MEMREAD);

    `assert_equal(uut.core.result, 32'ha8)
    `assert_equal(uut.core.memory__address, 32'ha8)

    wait_till_next_cfsm_state(MEMWB);

    `assert_equal(uut.core.data, 32'hdeadbeef)
    `assert_equal(uut.core.result, 32'hdeadbeef)

    wait_till_next_cfsm_state(FETCH);
    wait_till_next_cfsm_state(FETCH_WAIT);

    `assert_equal(uut.core.RegFile.RFMem[1], 32'hdeadbeef)
    `assert_equal(uut.core.RegFile.RFMem[2], 32'ha8)
    `assert_equal(uut.core.fetch.pc_cur, 4) // starting second instruction already

    wait_till_next_cfsm_state(DECODE);

    `assert_equal(uut.core.opcode, 7'b0000011)
    `assert_equal(uut.core.instruction_decode.rs1, 2)
    `assert_equal(uut.core.instruction_decode.rs2, 0)
    `assert_equal(uut.core.instruction_decode.imm_ext, 4)

    wait_till_next_cfsm_state(MEMADR);

    `assert_equal(uut.core.RegFile.RFMem[2], 32'ha8)
    `assert_equal(uut.core.alu.a, 32'ha8)
    `assert_equal(uut.core.alu.b, 4)
    `assert_equal(uut.core.alu.out, 32'hac)

    wait_till_next_cfsm_state(MEMREAD);

    `assert_equal(uut.core.result, 32'hac)
    `assert_equal(uut.core.memory__address, 32'hac)

    wait_till_next_cfsm_state(MEMWB);

    `assert_equal(uut.core.data, 32'hcafebabe)
    `assert_equal(uut.core.result, 32'hcafebabe)

    wait_till_next_cfsm_state(FETCH);
    wait_till_next_cfsm_state(FETCH_WAIT);

    `assert_equal(uut.core.RegFile.RFMem[1], 32'hcafebabe)
    `assert_equal(uut.core.RegFile.RFMem[2], 32'ha8)
    `assert_equal(uut.core.fetch.pc_cur, 8) // starting third instruction already

    wait_till_next_cfsm_state(DECODE);

    `assert_equal(uut.core.opcode, 7'b0000011)
    `assert_equal(uut.core.instruction_decode.rs1, 2)
    `assert_equal(uut.core.instruction_decode.rs2, 0)
    `assert_equal(uut.core.instruction_decode.imm_ext, -8)

    wait_till_next_cfsm_state(MEMADR);

    `assert_equal(uut.core.RegFile.RFMem[2], 32'ha8)
    `assert_equal(uut.core.alu.a, 32'ha8)
    `assert_equal(uut.core.alu.b, -8)
    `assert_equal(uut.core.alu.out, 32'ha0)

    wait_till_next_cfsm_state(MEMREAD);

    `assert_equal(uut.core.result, 32'ha0)
    `assert_equal(uut.core.memory__address, 32'ha0)

    wait_till_next_cfsm_state(MEMWB);

    `assert_equal(uut.core.data, 32'hbadab00f)
    `assert_equal(uut.core.result, 32'hbadab00f)

    wait_till_next_cfsm_state(FETCH);
    wait_till_next_cfsm_state(FETCH_WAIT);

    `assert_equal(uut.core.RegFile.RFMem[1], 32'hbadab00f)
    `assert_equal(uut.core.RegFile.RFMem[2], 32'ha8)
    `assert_equal(uut.core.fetch.pc_cur, 12)

    $finish;
  end

  `SETUP_VCD_DUMP(lw_tb)

endmodule
