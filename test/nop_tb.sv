`timescale 1ns/1ps

`include "test/utils.svh"

//generate clock (10ns period)
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

module nop_tb;

    //helper task to compare current state with the expected current state
    task wait_till_next_cfsm_state(input [5:0] expected_state);
        @(posedge clk); #1;
        `assert_equal(uut.control_fsm.current_state, expected_state)
    endtask

    //instantiate top module
    top cpucore ( .clk(clk), .reset(reset));

    initial begin
    
        reset <= `TRUE;

        //pre-write NOP instruction into instruction memory
        cpucore.memory.M[0] = 32'h00000013; //NOP instruction - addi x0, x0, 0

        //wait until reset makes FSM go to fetch state
        wait_till_next_cfsm_state(cpucore.control_fsm.FETCH);

        reset <= `FALSE;

        wait_till_next_cfsm_state(cpucore.control_fsm.DECODE);

        `assert_equal(cpucore.opcode, 7'b0010011)
        `assert_equal(cpucore.instruction_decode.rs1, 0)
        `assert_equal(cpucore.instruction_decode.rd, 0)
        `assert_equal(cpucore.instruction_decode.imm_ext, 0)

        wait_till_next_cfsm_state(uut.control_fsm.EXECUTEI);
        `assert_equal(uut.alu.a, 0)
        `assert_equal(uut.alu.b, 0)
        `assert_equal(uut.alu.out, 0)

        wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

        wait_till_next_cfsm_state(uut.control_fsm.FETCH);
        `assert_equal(uut.instruction_decode.instanceRegFile.RFMem[0], 0)
        `assert_equal(uut.fetch.pc_cur, 8)

    end

    `SETUP_VCD_DUMP(or_tb)


endmodule