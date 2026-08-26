`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

module zbkb_tb;

  import ext__b__types::*;

  localparam int XLEN = `PROCESSOR_BITNESS;
  localparam int SHIFT_WIDTH = $clog2(XLEN);

  logic [XLEN - 1:0] a, b;
  b_alu_control_t ctrl;
  logic [XLEN - 1:0] out;
  logic zeroE;

  int errors = 0;

  zbkb dut(.a(a), .b(b), .b_alu_control(ctrl), .out(out), .zeroE(zeroE));

  task automatic check(input [XLEN - 1:0] expected, input string name);
    #1;
    if (out !== expected) begin
      $error("[FAIL] %s: got %h, expected %h", name, out, expected);
      errors++;
    end else begin
      $display("[PASS] %s: %h", name, out);
    end
  endtask

  // reference model for rotate, used in property checks
  function automatic logic [XLEN - 1:0] ref_rol(input logic [XLEN - 1:0] v, input int s);
    ref_rol = (v << s) | (v >> (XLEN - s));
  endfunction

  initial begin
    // ---- ROL ----
    a = 32'h0000_0001; b = 1; ctrl = B_ALU_CTRL__ROL;
    check(32'h0000_0002, "rol by 1");

    a = 32'h8000_0000; b = 1; ctrl = B_ALU_CTRL__ROL;
    check(32'h0000_0001, "rol wraparound");

    a = 32'hDEAD_BEEF; b = 0; ctrl = B_ALU_CTRL__ROL;
    check(32'hDEAD_BEEF, "rol by 0 (identity)");

    // ---- ROR ----
    a = 32'h0000_0002; b = 1; ctrl = B_ALU_CTRL__ROR;
    check(32'h0000_0001, "ror by 1");

    a = 32'h0000_0001; b = 1; ctrl = B_ALU_CTRL__ROR;
    check(32'h8000_0000, "ror wraparound");

    // ---- RORI (same op as ROR, immediate routed via b) ----
    a = 32'h0000_0002; b = 1; ctrl = B_ALU_CTRL__RORI;
    check(32'h0000_0001, "rori by 1");

    // ---- ANDN ----
    a = 32'hFFFF_FFFF; b = 32'h0000_00FF; ctrl = B_ALU_CTRL__ANDN;
    check(32'hFFFF_FF00, "andn");

    // ---- ORN ----
    a = 32'h0000_0000; b = 32'h0000_00FF; ctrl = B_ALU_CTRL__ORN;
    check(32'hFFFF_FF00, "orn");

    // ---- XNOR ----
    a = 32'hAAAA_AAAA; b = 32'hAAAA_AAAA; ctrl = B_ALU_CTRL__XNOR;
    check(32'hFFFF_FFFF, "xnor equal operands");

    a = 32'hAAAA_AAAA; b = 32'h5555_5555; ctrl = B_ALU_CTRL__XNOR;
    check(32'h0000_0000, "xnor inverse operands");

    // ---- PACK ----
    a = 32'h0000_1234; b = 32'h0000_5678; ctrl = B_ALU_CTRL__PACK;
    check(32'h5678_1234, "pack");

    // ---- PACKH ----
    a = 32'hAAAA_AA12; b = 32'hBBBB_BB34; ctrl = B_ALU_CTRL__PACKH;
    check(32'h0000_3412, "packh");

    // ---- BREV8 ----
    a = 32'h1234_5678; b = '0; ctrl = B_ALU_CTRL__BREV8;
    check(32'h482C_6A1E, "brev8");

    a = 32'h0000_0000; ctrl = B_ALU_CTRL__BREV8;
    check(32'h0000_0000, "brev8 zero");

    a = 32'hFFFF_FFFF; ctrl = B_ALU_CTRL__BREV8;
    check(32'hFFFF_FFFF, "brev8 all-ones");

    // ---- REV8 ----
    a = 32'h1234_5678; ctrl = B_ALU_CTRL__REV8;
    check(32'h7856_3412, "rev8");

    // ---- zeroE flag ----
    a = 32'h0000_0000; b = 32'h0000_0000; ctrl = B_ALU_CTRL__ANDN;
    #1;
    if (zeroE !== 1'b1) begin
      $error("[FAIL] zeroE should be 1 when out==0");
      errors++;
    end else begin
      $display("[PASS] zeroE asserted correctly");
    end

    a = 32'h0000_0001; b = 32'h0000_0000; ctrl = B_ALU_CTRL__ANDN;
    #1;
    if (zeroE !== 1'b0) begin
      $error("[FAIL] zeroE should be 0 when out!=0");
      errors++;
    end else begin
      $display("[PASS] zeroE deasserted correctly");
    end

    // ---- Property: rol/ror are inverses ----
    for (int trial = 0; trial < 20; trial++) begin
      logic [XLEN - 1:0] rand_a;
      int shift;
      rand_a = $urandom;
      shift  = $urandom_range(0, XLEN - 1);

      a = rand_a; b = shift; ctrl = B_ALU_CTRL__ROL;
      #1;
      a = out; b = shift; ctrl = B_ALU_CTRL__ROR;
      #1;
      if (out !== rand_a) begin
        $error("[FAIL] rol/ror inverse property: shift=%0d, got %h, expected %h", shift, out, rand_a);
        errors++;
      end
    end
    $display("[PASS] rol/ror inverse property (20 random trials)");

    // ---- Property: brev8 is self-inverse ----
    for (int trial = 0; trial < 20; trial++) begin
      logic [XLEN - 1:0] rand_a, first;
      rand_a = $urandom;
      a = rand_a; ctrl = B_ALU_CTRL__BREV8;
      #1;
      first = out;
      a = first; ctrl = B_ALU_CTRL__BREV8;
      #1;
      if (out !== rand_a) begin
        $error("[FAIL] brev8 self-inverse: got %h, expected %h", out, rand_a);
        errors++;
      end
    end
    $display("[PASS] brev8 self-inverse property (20 random trials)");

    // ---- Property: rev8 is self-inverse ----
    for (int trial = 0; trial < 20; trial++) begin
      logic [XLEN - 1:0] rand_a, first;
      rand_a = $urandom;
      a = rand_a; ctrl = B_ALU_CTRL__REV8;
      #1;
      first = out;
      a = first; ctrl = B_ALU_CTRL__REV8;
      #1;
      if (out !== rand_a) begin
        $error("[FAIL] rev8 self-inverse: got %h, expected %h", out, rand_a);
        errors++;
      end
    end
    $display("[PASS] rev8 self-inverse property (20 random trials)");

    if (errors == 0)
      $display("\n=== ALL TESTS PASSED ===");
    else
      $display("\n=== %0d TEST(S) FAILED ===", errors);

    $finish;
  end

endmodule
