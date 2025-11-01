`timescale 1ns/1ps

`include "test/utils.svh"
`include "src/utils.svh"

module auipc_tb;

  logic clk;
  logic reset;

  top uut
    ( .clk ( clk )
    , .reset( reset )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task wait_till_next_cfsm_state(input [5:0] expected_state);
    @(posedge clk); #1;
    `assert_equal(uut.control_fsm.current_state, expected_state)
  endtask

  logic[31:0] tb_pc_old;

  initial begin
    reset <= `TRUE;

    //Set up memory
    //auipc rd, imm -> machine code: imm[31:12] | 11 rd 7 | 6 op 0
    uut.memory.M[ 0] = 32'h00014097; // auipc x1, 20
    uut.memory.M[ 1] = 32'h000c8117; // auipc x2, 200
    // 000c8 | 0001_0 | 001_0111
    uut.memory.M[ 2] = 32'h003ff197; // auipc x3, 1023
    uut.memory.M[40] = 32'hbadab00f; // have some data at address 0xa0
    uut.memory.M[42] = 32'hdeadbeef; // have some data at address 0xa8
    uut.memory.M[43] = 32'hcafebabe; // have some data at address 0xac

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    //imm ext should be changed to add a new case

    `assert_equal(uut.opcode, 7'b0010111)
    `assert_equal(uut.instruction_decode.imm_ext, 32'h00014000)

    //This will be a new FSM stage AUIPC:
    // 1. set SrcA to oldPC
    // 2. set SrcB to immext
    // 3. set ALU to ADD

    wait_till_next_cfsm_state(uut.control_fsm.AUIPC);
    tb_pc_old = uut.pc_old;
    `assert_equal(uut.alu_input_a, tb_pc_old)
    `assert_equal(uut.alu_input_b, 32'h00014000)
    `assert_equal(uut.__tmp_ALUControl, 4'b0)
    `assert_equal(uut.alu_result, 32'h00014000 + tb_pc_old)

    //This new state will be connected to ALUWB

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    `assert_equal(uut.instruction_decode.rd, 1)

    //Exe lui x2, 200
    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.RegFile.RFMem[1], 32'h00014000 + tb_pc_old)
    //x1 at this moment should be updated

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    //imm ext should be changed to add a new case

    `assert_equal(uut.opcode, 7'b0010111)
    `assert_equal(uut.instruction_decode.imm_ext, 32'h000c8000)

    wait_till_next_cfsm_state(uut.control_fsm.AUIPC);
    tb_pc_old = uut.pc_old;
    `assert_equal(uut.alu_input_a, tb_pc_old)
    `assert_equal(uut.alu_input_b, 32'h000c8000)
    `assert_equal(uut.__tmp_ALUControl, 4'b0)
    `assert_equal(uut.alu_result, 32'h000c8000 + tb_pc_old)

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    `assert_equal(uut.instruction_decode.rd, 2)

    //Exe lui x3, 1023
    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.RegFile.RFMem[2], 32'h000c8000 + tb_pc_old)

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    //imm ext should be changed to add a new case

    `assert_equal(uut.opcode, 7'b0010111)
    `assert_equal(uut.instruction_decode.imm_ext, 32'h003ff000)

    wait_till_next_cfsm_state(uut.control_fsm.AUIPC);
    tb_pc_old = uut.pc_old;
    `assert_equal(uut.alu_input_a, tb_pc_old)
    `assert_equal(uut.alu_input_b, 32'h003ff000)
    `assert_equal(uut.__tmp_ALUControl, 4'b0)
    `assert_equal(uut.alu_result, 32'h003ff000 + tb_pc_old)

    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    `assert_equal(uut.instruction_decode.rd, 3)

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    `assert_equal(uut.RegFile.RFMem[3], 32'h003ff000 + tb_pc_old)

    //If the simulation makes to this point, the simulation passed

    $display("auipc verified, Test Passed");
    $finish;

  end

  `SETUP_VCD_DUMP(auipc_tb)

endmodule
