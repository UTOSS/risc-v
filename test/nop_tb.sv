`timescale 1ns/1ps

`include "test/utils.svh"

module nop_tb;

    reg clk;
    reg reset;

    //instantiate top module
    top uut ( .clk(clk), .reset(reset) );

    //helper task to compare current state with the expected current state
    task wait_till_next_cfsm_state(input [5:0] expected_state);
        @(posedge clk); #1;
        `assert_equal(uut.control_fsm.current_state, expected_state)
    endtask

    //generate clock (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin

        reset <= `TRUE;

        //pre-write NOP instruction into instruction memory
        uut.memory.M[0] = 32'h00000013; //NOP instruction - addi x0, x0, 0

        // set up register file to a known value
        uut.instruction_decode.instanceRegFile.RFMem[0] = 32'h01010101; // x0, and it should still be 0 even we try to write it as 0

        //wait until reset makes FSM go to fetch state
        wait_till_next_cfsm_state(uut.control_fsm.FETCH);

        reset <= `FALSE;

        wait_till_next_cfsm_state(uut.control_fsm.DECODE);

        `assert_equal(uut.opcode, 7'b0010011)
        `assert_equal(uut.instruction_decode.rs1, 0)
        `assert_equal(uut.instruction_decode.rd, 0)
        `assert_equal(uut.instruction_decode.imm_ext, 0)

        wait_till_next_cfsm_state(uut.control_fsm.EXECUTEI);
        `assert_equal(uut.alu.a, 32'h0)
        `assert_equal(uut.alu.b, 0)
        `assert_equal(uut.alu.out, 32'h0)

        wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

        wait_till_next_cfsm_state(uut.control_fsm.FETCH);
        `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[0], 32'h0)
        `assert_equal(uut.fetch.pc_cur, 4)

        $finish;

    end

    `SETUP_VCD_DUMP(nop_tb)


endmodule
