`timescale 1ns/1ps

`include "test/utils.svh"

module memoryload_tb;

  reg clk;
  reg reset;
  integer expected_pc = 0;

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

  task check_next_memory_read(input [31:0] expected_addr, input [31:0] expected_word);
    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH_WAIT);

    wait_till_next_cfsm_state(uut.core.control_fsm.DECODE);

    `assert_equal(uut.core.opcode, 7'b0000011)
    `assert_equal(uut.core.instruction_decode.rs1, 2)
    `assert_equal(uut.core.instruction_decode.imm_ext, expected_addr - 32'h10)

    wait_till_next_cfsm_state(uut.core.control_fsm.MEMADR);

    `assert_equal(uut.core.alu.a, 32'h10)
    `assert_equal(uut.core.alu.b, expected_addr - 32'h10)
    `assert_equal(uut.core.alu.out, expected_addr)

    wait_till_next_cfsm_state(uut.core.control_fsm.MEMREAD);

    `assert_equal(uut.core.result, expected_addr)
    `assert_equal(uut.memory__address, expected_addr)

    wait_till_next_cfsm_state(uut.core.control_fsm.MEMWB);

    `assert_equal(uut.core.data, expected_word)
    `assert_equal(uut.core.result, expected_word)

    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);

    `assert_equal(uut.core.RegFile.RFMem[1], expected_word)
    expected_pc = expected_pc + 4;
    `assert_equal(uut.core.fetch.pc_cur, expected_pc)
  endtask

  initial begin
    reset <= `TRUE;

    // set up instructions and data memory; M array uses word addressing, hence the indices there
    // are 4 times smaller than the actual addresses corresponding to the beginning to the
    // corresponding word
    uut.memory.M[ 0] = 32'h09010083; // lb x1, 0x90(x2)
    uut.memory.M[ 1] = 32'h09110083; // lb x1, 0x91(x2)
    uut.memory.M[ 2] = 32'h09210083; // lb x1, 0x92(x2)
    uut.memory.M[ 3] = 32'h09310083; // lb x1, 0x93(x2)
    uut.memory.M[ 4] = 32'h09810083; // lb x1, 0x98(x2)
    uut.memory.M[ 5] = 32'h09910083; // lb x1, 0x99(x2)
    uut.memory.M[ 6] = 32'h09a10083; // lb x1, 0x9a(x2)
    uut.memory.M[ 7] = 32'h09b10083; // lb x1, 0x9b(x2)

    uut.memory.M[ 8] = 32'h09014083; // lbu x1, 0x90(x2)
    uut.memory.M[ 9] = 32'h09114083; // lbu x1, 0x91(x2)
    uut.memory.M[10] = 32'h09214083; // lbu x1, 0x92(x2)
    uut.memory.M[11] = 32'h09314083; // lbu x1, 0x93(x2)
    uut.memory.M[12] = 32'h09814083; // lbu x1, 0x98(x2)
    uut.memory.M[13] = 32'h09914083; // lbu x1, 0x99(x2)
    uut.memory.M[14] = 32'h09a14083; // lbu x1, 0x9a(x2)
    uut.memory.M[15] = 32'h09b14083; // lbu x1, 0x9b(x2)

    uut.memory.M[16] = 32'h09011083; // lh x1, 0x90(x2)
    uut.memory.M[17] = 32'h09211083; // lh x1, 0x92(x2)
    uut.memory.M[18] = 32'h09811083; // lh x1, 0x98(x2)
    uut.memory.M[19] = 32'h09a11083; // lh x1, 0x9a(x2)

    uut.memory.M[20] = 32'h09015083; // lhu x1, 0x90(x2)
    uut.memory.M[21] = 32'h09215083; // lhu x1, 0x92(x2)
    uut.memory.M[22] = 32'h09815083; // lhu x1, 0x98(x2)
    uut.memory.M[23] = 32'h09a15083; // lhu x1, 0x9a(x2)

    // Check that the sign bits don't use the wrong bits.
    uut.memory.M[24] = 32'h0a010083; // lb x1, 0xa0(x2)
    uut.memory.M[25] = 32'h0a510083; // lb x1, 0xa5(x2)
    uut.memory.M[26] = 32'h0aa10083; // lb x1, 0xaa(x2)
    uut.memory.M[27] = 32'h0af10083; // lb x1, 0xaf(x2)
    uut.memory.M[28] = 32'h0a411083; // lh x1, 0xa4(x2)
    uut.memory.M[29] = 32'h0a611083; // lh x1, 0xa6(x2)
    uut.memory.M[30] = 32'h0a811083; // lh x1, 0xa8(x2)
    uut.memory.M[31] = 32'h0aa11083; // lh x1, 0xaa(x2)

    // remember the endian-ness! Here, 0xa0-->0x11, even though it might look
    // like it should be 0x44.
    uut.memory.M[40] = 32'h44332211; // address 0xa0
    uut.memory.M[42] = 32'hc7d6e5f4; // address 0xa8

    uut.memory.M[44] = 32'h00000080; // address 0xb0
    uut.memory.M[45] = 32'h00008000; // address 0xb4
    uut.memory.M[46] = 32'h00800000; // address 0xb8
    uut.memory.M[47] = 32'h80000000; // address 0xbc

    uut.core.RegFile.RFMem[2] = 32'h10;

    wait_till_next_cfsm_state(uut.core.control_fsm.FETCH);
    reset <= `FALSE;

    // signed byte reads
    check_next_memory_read(32'ha0, 32'h00000011);
    check_next_memory_read(32'ha1, 32'h00000022);
    check_next_memory_read(32'ha2, 32'h00000033);
    check_next_memory_read(32'ha3, 32'h00000044);
    check_next_memory_read(32'ha8, 32'hfffffff4);
    check_next_memory_read(32'ha9, 32'hffffffe5);
    check_next_memory_read(32'haa, 32'hffffffd6);
    check_next_memory_read(32'hab, 32'hffffffc7);

    // unsigned byte reads
    check_next_memory_read(32'ha0, 32'h00000011);
    check_next_memory_read(32'ha1, 32'h00000022);
    check_next_memory_read(32'ha2, 32'h00000033);
    check_next_memory_read(32'ha3, 32'h00000044);
    check_next_memory_read(32'ha8, 32'h000000f4);
    check_next_memory_read(32'ha9, 32'h000000e5);
    check_next_memory_read(32'haa, 32'h000000d6);
    check_next_memory_read(32'hab, 32'h000000c7);

    // signed half reads
    check_next_memory_read(32'ha0, 32'h00002211);
    check_next_memory_read(32'ha2, 32'h00004433);
    check_next_memory_read(32'ha8, 32'hffffe5f4);
    check_next_memory_read(32'haa, 32'hffffc7d6);

    // unsigned half reads
    check_next_memory_read(32'ha0, 32'h00002211);
    check_next_memory_read(32'ha2, 32'h00004433);
    check_next_memory_read(32'ha8, 32'h0000e5f4);
    check_next_memory_read(32'haa, 32'h0000c7d6);

    // single-high-bit sign checks (byte)
    check_next_memory_read(32'hb0, 32'hffffff80);
    check_next_memory_read(32'hb5, 32'hffffff80);
    check_next_memory_read(32'hba, 32'hffffff80);
    check_next_memory_read(32'hbf, 32'hffffff80);

    // single-high-bit sign checks (half)
    check_next_memory_read(32'hb4, 32'hffff8000);
    check_next_memory_read(32'hb6, 32'h00000000);
    check_next_memory_read(32'hb8, 32'h00000000);
    check_next_memory_read(32'hba, 32'h00000080);

    $finish;
  end

  `SETUP_VCD_DUMP(memoryload_tb)

endmodule
