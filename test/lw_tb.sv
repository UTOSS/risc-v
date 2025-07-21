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
    assert(uut.control_fsm.current_state == expected_state)
      else $fatal(1,"`uut.control_fsm.state` is `%0d`", uut.control_fsm.current_state);
  endtask

  initial begin
    reset <= `TRUE;

    // set up instrctions and data memory
    uut.memory.M[ 0] = 32'h00012083; // lw x1, 0(x2)
    uut.memory.M[42] = 32'hdeadbeef; // have some data at address 42

    // set up register file
    uut.instruction_decode.instanceRegFile.RFMem[2] = 32'h0000002a; // x1 = 42

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    reset <= `FALSE;

    wait_till_next_cfsm_state(uut.control_fsm.DECODE);

    assert(uut.opcode == 7'b0000011) else $fatal(1,"`uut.opcode` is `%0b`", uut.opcode);
    assert(uut.instruction_decode.rs1 == 2)
      else $fatal(1,"`uut.instruction_decode.rs1` is `%0d`", uut.instruction_decode.rs1);
    assert(uut.instruction_decode.rs2 == 0)
      else $fatal(1,"`uut.instruction_decode.rs2` is `%0d`", uut.instruction_decode.rs2);
    assert(uut.instruction_decode.imm_ext == 32'h00000000)
      else $fatal(1,"`uut.fetch.imm_ext` is `%0h`", uut.fetch.imm_ext);

    wait_till_next_cfsm_state(uut.control_fsm.MEMADR);

    assert(uut.instruction_decode.instanceRegFile.RFMem[2] == 32'h0000002a)
      else $fatal(1,"`uut.instruction_decode.instanceRegFile.RFMem[2]` is `%0h`", uut.instruction_decode.instanceRegFile.RFMem[2]);
    assert(uut.alu.a == 32'h0000002a) else $fatal(1,"`uut.alu.a` is `%0h`", uut.alu.a);
    assert(uut.alu.b == 32'h00000000) else $fatal(1,"`uut.alu.b` is `%0h`", uut.alu.b);
    assert(uut.alu.out == 32'h0000002a) else $fatal(1,"`uut.alu.out` is `%0h`", uut.alu.out);

    wait_till_next_cfsm_state(uut.control_fsm.MEMREAD);

    assert(uut.result == 32'h0000002a) else $fatal(1,"`uut.result` is `%0h`", uut.result);
    assert(uut.memory_address == 32'h0000002a)
      else $fatal(1,"`uut.memory_address` is `%0h`", uut.memory_address);

    wait_till_next_cfsm_state(uut.control_fsm.MEMWB);

    assert(uut.data == 32'hdeadbeef) else $fatal(1,"`uut.data` is `%0h`", uut.data);
    assert(uut.result == 32'hdeadbeef) else $fatal(1,"`uut.result` is `%0h`", uut.result);

    wait_till_next_cfsm_state(uut.control_fsm.FETCH);

    assert(uut.instruction_decode.instanceRegFile.RFMem[1] == 32'hdeadbeef)
      else $fatal(1,"`uut.instruction_decode.instanceRegFile.RFMem[1]` is `%0h`", uut.instruction_decode.instanceRegFile.RFMem[1]);
    assert(uut.instruction_decode.instanceRegFile.RFMem[2] == 32'h0000002a)
      else $fatal(1,"`uut.instruction_decode.instanceRegFile.RFMem[2]` is `%0h`", uut.instruction_decode.instanceRegFile.RFMem[2]);
    assert(uut.fetch.pc_cur == 32'h00000004) else $fatal(1,"`uut.fetch.pc_cur` is `%0h`", uut.fetch.pc_cur);

  end

  `SETUP_VCD_DUMP(lw_tb)

endmodule
