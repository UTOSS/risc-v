`include "src/timescale.svh"

`include "test/utils.svh"

/* verilator lint_off IMPORTSTAR */
import pkg_control_fsm::*;
/* verilator lint_on IMPORTSTAR */

module pipeline_edge_case_2_tb;

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

  task tick;
    @(posedge clk); #1;
  endtask

  initial begin
    reset = `TRUE;

    // Program relocated to address 0:
    //   lw   a5, -20(s0)
    //   addi a5, a5, 1
    //   sw   a5, -20(s0)
    //   lw   a4, -20(s0)
    //   lui  a5, 0xf4
    //   addi a5, a5, 575
    uut.u_memory.M[0] = 32'hfec42783;
    uut.u_memory.M[1] = 32'h00178793;
    uut.u_memory.M[2] = 32'hfef42623;
    uut.u_memory.M[3] = 32'hfec42703;
    uut.u_memory.M[4] = 32'h000f47b7;
    uut.u_memory.M[5] = 32'h23f78793;

    // Drain with nops.
    uut.u_memory.M[6]  = 32'h00000013;
    uut.u_memory.M[7]  = 32'h00000013;
    uut.u_memory.M[8]  = 32'h00000013;
    uut.u_memory.M[9]  = 32'h00000013;
    uut.u_memory.M[10] = 32'h00000013;
    uut.u_memory.M[11] = 32'h00000013;

    // s0 = 0xb4 so -20(s0) = 0xa0 (byte address), which maps to M[40].
    uut.core.u_decode_stage.RegFile.RFMem[8]  = 32'h000000b4;
    uut.core.u_decode_stage.RegFile.RFMem[15] = 32'hdeadbeef;
    uut.core.u_decode_stage.RegFile.RFMem[14] = 32'hcafebabe;

    // Initial value at -20(s0) is zero.
    uut.u_memory.M[40] = 32'h00000000;

    tick();
    reset = `FALSE;

    repeat (120) tick();

    // After lw/addi/sw, -20(s0) should hold the incremented value 1.
    `assert_equal(uut.u_memory.M[40], 32'h00000001)

    // Final a5 after lui/addi must be 0x000f423f.
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[15], 32'h000f423f)

    $finish;
  end

  `SETUP_VCD_DUMP(pipeline_edge_case_2_tb)

endmodule
