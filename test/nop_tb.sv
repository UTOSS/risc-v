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
        `assert_equal(uut.core.control_fsm.current_state, expected_state)
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
        uut.core.RegFile.RFMem[0] = 32'h01010101; // x0, hould still be 0 even we try to write it as 0

        //wait until reset makes FSM go to fetch state
        wait_till_next_cfsm_state(FETCH);

        reset <= `FALSE;

        wait_till_next_cfsm_state(FETCH_WAIT);

        wait_till_next_cfsm_state(DECODE);

        `assert_equal(uut.core.opcode, 7'b0010011)
        `assert_equal(uut.core.instruction_decode.rs1, 0)
        `assert_equal(uut.core.instruction_decode.rd, 0)
        `assert_equal(uut.core.instruction_decode.imm_ext, 0)

        wait_till_next_cfsm_state(EXECUTEI);
        `assert_equal(uut.core.alu.a, 32'h0)
        `assert_equal(uut.core.alu.b, 0)
        `assert_equal(uut.core.alu.out, 32'h0)

        wait_till_next_cfsm_state(ALUWB);

        wait_till_next_cfsm_state(FETCH);
        wait_till_next_cfsm_state(FETCH_WAIT);
        `assert_equal(uut.core.RegFile.RFMem[0], 32'h0)
        `assert_equal(uut.core.fetch.pc_cur, 4)

        $finish;

    end

    `SETUP_VCD_DUMP(nop_tb)


endmodule
