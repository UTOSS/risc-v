`timescale 1ns/1ps

`include "src/types.svh"      // <-- bring in enum literals like PC_SRC__JUMP
`include "test/utils.svh"

module jal_only_tb;

  reg clk;
  reg reset;

  // DUT
  utoss_riscv uut
    ( .clk   ( clk   )
    , .reset ( reset )
    );

  // 10ns clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // helper: wait one cycle then assert expected FSM state
  task wait_till_next_cfsm_state(input [3:0] expected_state);
    @(posedge clk); #1;
    `assert_equal(uut.control_fsm.current_state, expected_state)
  endtask

  initial begin
    reset <= `TRUE;

    // Program:
    //   0x00000000: JAL x1, +16   (target = 16)
    // J-type encoding: opcode=0x6F, rd=x1, imm=+16 -> 0x010000EF
    uut.memory.M[0] = 32'h010000EF;

    // Enter FETCH first (with reset asserted)
    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    // Release reset
    reset <= `FALSE;

    // -------- Single instruction: JAL x1, +16 --------

    // DECODE: verify opcode, rd and immediate
    wait_till_next_cfsm_state(uut.control_fsm.DECODE);
    `assert_equal(uut.opcode, 7'b1101111)                    // JType (JAL)
    `assert_equal(uut.instruction_decode.rd,  5'd1)          // rd = x1
    `assert_equal(uut.instruction_decode.imm_ext, 32'sd16)   // imm = +16

    // UNCONDJUMP: link = pc_old + 4, PC updates by pc + imm
    wait_till_next_cfsm_state(uut.control_fsm.UNCONDJUMP);
    `assert_equal(uut.alu.a, 32'd0)    // pc_old at address 0
    `assert_equal(uut.alu.b, 32'd4)
    `assert_equal(uut.alu.out, 32'd4)  // link value
    `assert_equal(uut.cfsm__pc_update, 1'b1)
    `assert_equal(uut.cfsm__pc_src, PC_SRC__JUMP)  // <-- enum literal, no hierarchy

    // ALUWB: write link back to rd (x1)
    wait_till_next_cfsm_state(uut.control_fsm.ALUWB);

    // Back to FETCH: PC should be 16; x1 should be 4
    wait_till_next_cfsm_state(uut.control_fsm.FETCH);
    `assert_equal(uut.RegFile.RFMem[1], 32'd4)  // rd = link = 4
    `assert_equal(uut.fetch.pc_cur, 32'd16)                                 // PC jumped to 16

    $finish;
  end

  `SETUP_VCD_DUMP(jal_only_tb)

endmodule
