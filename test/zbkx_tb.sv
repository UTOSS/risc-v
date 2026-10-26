`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

module zbkx_tb;

  import ext__b__types::*;

  localparam int XLEN = `PROCESSOR_BITNESS;

  logic [XLEN - 1:0] a, b;
  b_alu_control_t ctrl;
  logic [XLEN - 1:0] out;
  logic zeroE;

  int errors = 0;

  zbkx dut(.a(a), .b(b), .b_alu_control(ctrl), .out(out), .zeroE(zeroE));

  task automatic check(input [XLEN - 1:0] expected, input string name);
    #1;
    if (out !== expected) begin
      $error("[FAIL] %s: got %h, expected %h", name, out, expected);
      errors++;
    end else begin
      $display("[PASS] %s: %h", name, out);
    end
  endtask

  initial begin
    // XPERM8
    a = 32'h44332211; b = 32'h00010203; ctrl = B_ALU_CTRL__XPERM8;
    check(32'h11223344, "xperm8 reverse bytes");

    a = 32'h11223344; b = 32'h08080808; ctrl = B_ALU_CTRL__XPERM8;
    check(32'h00000000, "xperm8 out of range");

    a = 32'h11223344; b = 32'h00040004; ctrl = B_ALU_CTRL__XPERM8;
    check(32'h44004400, "xperm8 mixed in and out of range");

    // XPERM4
    a = 32'h12345678; b = 32'h87654321; ctrl = B_ALU_CTRL__XPERM4;
    check(32'h01234567, "xperm4 lookup");

    a = 32'h11111111; b = 32'h99999999; ctrl = B_ALU_CTRL__XPERM4;
    check(32'h00000000, "xperm4 lookup out of range");

    // ---- zeroE flag ----
    a = 32'h0000_0000; b = 32'h0000_0000; ctrl = B_ALU_CTRL__XPERM4;
    #1;
    if (zeroE !== 1'b1) begin
      $error("[FAIL] zeroE should be 1 when out==0");
      errors++;
    end else begin
      $display("[PASS] zeroE asserted correctly");
    end

    a = 32'h0000_0001; b = 32'h0000_0000; ctrl = B_ALU_CTRL__XPERM8;
    #1;
    if (zeroE !== 1'b0) begin
      $error("[FAIL] zeroE should be 0 when out!=0");
      errors++;
    end else begin
      $display("[PASS] zeroE deasserted correctly");
    end

    if (errors == 0)
      $display("\n=== ALL TESTS PASSED ===");
    else
      $display("\n=== %0d TEST(S) FAILED ===", errors);

    $finish;

  end

endmodule
