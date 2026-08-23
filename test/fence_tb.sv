`include "src/timescale.svh"

`include "test/utils.svh"

module fence_tb;

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
    static bit saw_is_fence_decode = 0;
    static bit saw_is_fence_mem    = 0;

    reset = `TRUE;

    // 0: addi x1, x0, 10       (32'h00a00093) -> x1 = 10
    // 1: fence rw, rw          (32'h0ff0000f) -> pred=RW, succ=RW
    // 2: addi x2, x1, 5        (32'h00508113) -> x2 = 15
    // 3: sw   x2, 0(x0)        (32'h00202023) -> Mem[0] = 15
    // 4: fence w, r            (32'h0120000f) -> pred=W, succ=R
    // 5: lw   x3, 0(x0)        (32'h00002183) -> x3 = Mem[0] = 15
    // 6: nop                   (32'h00000013)
    // 7: nop                   (32'h00000013)
    // 8: nop                   (32'h00000013)
    // 9: nop                   (32'h00000013)

    uut.u_memory.M[0] = 32'h00a00093;
    uut.u_memory.M[1] = 32'h0ff0000f;
    uut.u_memory.M[2] = 32'h00508113;
    uut.u_memory.M[3] = 32'h00202023;
    uut.u_memory.M[4] = 32'h0120000f;
    uut.u_memory.M[5] = 32'h00002183;
    uut.u_memory.M[6] = 32'h00000013;
    uut.u_memory.M[7] = 32'h00000013;
    uut.u_memory.M[8] = 32'h00000013;
    uut.u_memory.M[9] = 32'h00000013;

    tick();
    reset = `FALSE;

    // Monitor internal pipeline signals during execution
    repeat (50) begin
      tick();

      if (uut.core.u_decode_stage.is_fence) begin
        saw_is_fence_decode = 1;
      end

      if (uut.core.u_memory_stage.fence_req) begin
        saw_is_fence_mem = 1;
      end
    end

    //Confirm FENCE was decoded and reached the Memory stage
    assert (saw_is_fence_decode)
      else $fatal(1, "Expected is_fence to assert in Decode stage");

    assert (saw_is_fence_mem)
      else $fatal(1, "Expected fence_req to assert in Memory stage");

    //Confirm computation results are accurate
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[1], 32'd10)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[2], 32'd15)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[3], 32'd15)
    `assert_equal(uut.u_memory.M[0], 32'd15)

    $display("[PASS] fence_tb completed successfully.");
    $finish;
  end

  `SETUP_VCD_DUMP(fence_tb)

endmodule
