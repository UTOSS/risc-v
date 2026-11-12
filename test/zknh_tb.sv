`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zknh/types.svh"

module zknh_tb;

  import ext__zknh__types::*;

  localparam int XLEN = `PROCESSOR_BITNESS;

  logic [XLEN - 1:0] a, b;
  zknh_control_t ctrl;
  logic [XLEN - 1:0] out;
  logic zeroE;

  logic [2:0] funct3;
  logic [6:0] funct7;
  opcode_t opcode;
  reg_t rs2;
  zknh_control_t decoded;

  int errors = 0;

  ext__zknh__logic dut(.a(a), .b(b), .zknh_control(ctrl), .out(out), .zeroE(zeroE));
  ext__zknh__decoder dec
    ( .funct3        ( funct3  )
    , .funct7        ( funct7  )
    , .opcode        ( opcode  )
    , .rs2           ( rs2     )
    , .zknh_control  ( decoded )
    );

  // also check the encoding through Instruction_Decode
  logic [31:0] instr;
  logic [2:0] dec_funct3;
  reg_t dec_rd, dec_rs1, dec_rs2;
  alu_control_t dec_alu_control;
  imm_t dec_imm_ext;
  opcode_t dec_opcode;
`ifdef UTOSS_RISCV_ENABLE_ZKNH_EXT
  zknh_control_t id_zknh_control;

  Instruction_Decode u_instruction_decode
    ( .instr        ( instr           )
    , .opcode       ( dec_opcode      )
    , .ALUControl   ( dec_alu_control )
    , .imm_ext      ( dec_imm_ext     )
    , .funct3       ( dec_funct3      )
    , .rd           ( dec_rd          )
    , .rs1          ( dec_rs1         )
    , .rs2          ( dec_rs2         )
    , .zknh_control ( id_zknh_control )
    );

  task automatic check_instr(input logic [31:0] word, input zknh_control_t expected, input string name);
    instr = word;
    #1;
    if (id_zknh_control !== expected) begin
      $error("[FAIL] decode %s: got %0d, expected %0d", name, int'(id_zknh_control), int'(expected));
      errors++;
    end else begin
      $display("[PASS] decode %s", name);
    end
  endtask
`endif

  task automatic check(input [XLEN - 1:0] expected, input string name);
    #1;
    if (out !== expected) begin
      $error("[FAIL] %s: got %h, expected %h", name, out, expected);
      errors++;
    end else begin
      $display("[PASS] %s: %h", name, out);
    end
  endtask

  task automatic check_decode(input zknh_control_t expected, input string name);
    #1;
    if (decoded !== expected) begin
      $error("[FAIL] decode %s: got %0d, expected %0d", name, int'(decoded), int'(expected));
      errors++;
    end else begin
      $display("[PASS] decode %s", name);
    end
  endtask

  // reference models: sha256 from the 32-bit rotations, sha512 from the 64-bit
  // transforms (the RV32 instructions return one half of those)
  function automatic logic [XLEN - 1:0] ref_ror32(input logic [XLEN - 1:0] v, input int s);
    ref_ror32 = (v >> s) | (v << (XLEN - s));
  endfunction

  function automatic logic [63:0] ref_ror64(input logic [63:0] v, input int s);
    ref_ror64 = (v >> s) | (v << (64 - s));
  endfunction

  function automatic logic [63:0] ref_sig0(input logic [63:0] x);
    ref_sig0 = ref_ror64(x, 1) ^ ref_ror64(x, 8) ^ (x >> 7);
  endfunction

  function automatic logic [63:0] ref_sig1(input logic [63:0] x);
    ref_sig1 = ref_ror64(x, 19) ^ ref_ror64(x, 61) ^ (x >> 6);
  endfunction

  function automatic logic [63:0] ref_sum0(input logic [63:0] x);
    ref_sum0 = ref_ror64(x, 28) ^ ref_ror64(x, 34) ^ ref_ror64(x, 39);
  endfunction

  function automatic logic [63:0] ref_sum1(input logic [63:0] x);
    ref_sum1 = ref_ror64(x, 14) ^ ref_ror64(x, 18) ^ ref_ror64(x, 41);
  endfunction

  // run one operand pair through every Zknh op; a = low half, b = high half
  task automatic check_pair(input logic [XLEN - 1:0] lo, input logic [XLEN - 1:0] hi, input string tag);
    logic [63:0] x_hl;
    logic [63:0] x_lh;
    begin
      x_hl = {hi, lo};
      x_lh = {lo, hi};
      a = lo;
      b = hi;

      ctrl = ZKNH_CTRL__SHA256SUM0;
      check(XLEN'(ref_ror32(lo, 2) ^ ref_ror32(lo, 13) ^ ref_ror32(lo, 22)), {tag, " sha256sum0"});

      ctrl = ZKNH_CTRL__SHA256SUM1;
      check(XLEN'(ref_ror32(lo, 6) ^ ref_ror32(lo, 11) ^ ref_ror32(lo, 25)), {tag, " sha256sum1"});

      ctrl = ZKNH_CTRL__SHA256SIG0;
      check(XLEN'(ref_ror32(lo, 7) ^ ref_ror32(lo, 18) ^ (lo >> 3)), {tag, " sha256sig0"});

      ctrl = ZKNH_CTRL__SHA256SIG1;
      check(XLEN'(ref_ror32(lo, 17) ^ ref_ror32(lo, 19) ^ (lo >> 10)), {tag, " sha256sig1"});

      ctrl = ZKNH_CTRL__SHA512SUM0R;
      check(XLEN'(ref_sum0(x_hl)), {tag, " sha512sum0r"});

      ctrl = ZKNH_CTRL__SHA512SUM1R;
      check(XLEN'(ref_sum1(x_hl)), {tag, " sha512sum1r"});

      ctrl = ZKNH_CTRL__SHA512SIG0L;
      check(XLEN'(ref_sig0(x_hl)), {tag, " sha512sig0l"});

      ctrl = ZKNH_CTRL__SHA512SIG1L;
      check(XLEN'(ref_sig1(x_hl)), {tag, " sha512sig1l"});

      // h forms swap the operand pair
      ctrl = ZKNH_CTRL__SHA512SIG0H;
      check(XLEN'(ref_sig0(x_lh) >> 32), {tag, " sha512sig0h"});

      ctrl = ZKNH_CTRL__SHA512SIG1H;
      check(XLEN'(ref_sig1(x_lh) >> 32), {tag, " sha512sig1h"});
    end
  endtask

  initial begin
    // ---- Decoder: SHA2-256 instructions (OP-IMM, funct3 = 001, funct7 = 0001000) ----
    opcode = OPCODE_OP_IMM;
    funct3 = 3'b001;
    funct7 = 7'b0001000;

    rs2 = 5'd0;
    check_decode(ZKNH_CTRL__SHA256SUM0, "sha256sum0 encoding");
    rs2 = 5'd1;
    check_decode(ZKNH_CTRL__SHA256SUM1, "sha256sum1 encoding");
    rs2 = 5'd2;
    check_decode(ZKNH_CTRL__SHA256SIG0, "sha256sig0 encoding");
    rs2 = 5'd3;
    check_decode(ZKNH_CTRL__SHA256SIG1, "sha256sig1 encoding");

    rs2 = 5'd4;
    check_decode(ZKNH_CTRL__NONE, "sha256 reserved rs2");
    rs2 = 5'd31;
    check_decode(ZKNH_CTRL__NONE, "sha256 reserved rs2 (max)");

    funct7 = 7'b0000000;
    rs2 = 5'd0;
    check_decode(ZKNH_CTRL__NONE, "slli is not Zknh");

    funct7 = 7'b0001000;
    funct3 = 3'b101;
    check_decode(ZKNH_CTRL__NONE, "OP-IMM funct3 is not 001");

    // ---- Decoder: SHA2-512 instructions (OP, funct3 = 000) ----
    opcode = OPCODE_OP;
    funct3 = 3'b000;
    rs2 = 5'd1;

    funct7 = 7'b0101000;
    check_decode(ZKNH_CTRL__SHA512SUM0R, "sha512sum0r encoding");
    funct7 = 7'b0101001;
    check_decode(ZKNH_CTRL__SHA512SUM1R, "sha512sum1r encoding");
    funct7 = 7'b0101010;
    check_decode(ZKNH_CTRL__SHA512SIG0L, "sha512sig0l encoding");
    funct7 = 7'b0101011;
    check_decode(ZKNH_CTRL__SHA512SIG1L, "sha512sig1l encoding");
    funct7 = 7'b0101110;
    check_decode(ZKNH_CTRL__SHA512SIG0H, "sha512sig0h encoding");
    funct7 = 7'b0101111;
    check_decode(ZKNH_CTRL__SHA512SIG1H, "sha512sig1h encoding");

    funct7 = 7'b0000000;
    check_decode(ZKNH_CTRL__NONE, "add is not Zknh");
    funct7 = 7'b0100000;
    check_decode(ZKNH_CTRL__NONE, "sub is not Zknh");
    funct7 = 7'b0001000;
    check_decode(ZKNH_CTRL__NONE, "OP funct7 is not a SHA2-512 encoding");

    funct7 = 7'b0101000;
    funct3 = 3'b001;
    check_decode(ZKNH_CTRL__NONE, "OP funct3 is not 000");

    funct3 = 3'b000;
    opcode = OPCODE_LOAD;
    check_decode(ZKNH_CTRL__NONE, "load is not Zknh");

`ifdef UTOSS_RISCV_ENABLE_ZKNH_EXT
    // ---- Encoding-level check with real instruction words ----
    check_instr(32'h1001_1093, ZKNH_CTRL__SHA256SUM0, "sha256sum0 x1, x2");
    check_instr(32'h1033_1293, ZKNH_CTRL__SHA256SIG1, "sha256sig1 x5, x6");
    check_instr(32'h5031_00B3, ZKNH_CTRL__SHA512SUM0R, "sha512sum0r x1, x2, x3");
    check_instr(32'h5E94_03B3, ZKNH_CTRL__SHA512SIG1H, "sha512sig1h x7, x8, x9");
    check_instr(32'h0311_093, ZKNH_CTRL__NONE, "slli x1, x2, 3");
    check_instr(32'h0310_0B3, ZKNH_CTRL__NONE, "add x1, x2, x3");
`endif

    // ---- Datapath: fixed operand pairs ----
    check_pair(32'h1234_5678, 32'h9ABC_DEF0, "vector-1");
    check_pair(32'h0000_0000, 32'h0000_0000, "zeros");
    check_pair(32'hFFFF_FFFF, 32'hFFFF_FFFF, "all-ones");
    check_pair(32'h8000_0001, 32'h7FFF_FFFE, "msb-set");

    // ---- H0/H1 constants ----
    // Sigma0(H0), Sigma1(H0), sigma0(H1), sigma1(H1) appear in the first round
    a = 32'h6A09_E667;
    ctrl = ZKNH_CTRL__SHA256SUM0;
    check(32'hCE20_B47E, "sha256sum0 of H0"); // Sigma0(H0)
    ctrl = ZKNH_CTRL__SHA256SUM1;
    check(32'h55B6_5510, "sha256sum1 of H0"); // Sigma1(H0)

    a = 32'hBB67_AE85;
    ctrl = ZKNH_CTRL__SHA256SIG0;
    check(32'hF7BB_5454, "sha256sig0 of H1"); // sigma0(H1)
    ctrl = ZKNH_CTRL__SHA256SIG1;
    check(32'h22BC_B334, "sha256sig1 of H1"); // sigma1(H1)

    // ---- Zero flag ----
    a = '0; b = '0; ctrl = ZKNH_CTRL__SHA256SIG0;
    #1;
    if (zeroE !== 1'b1) begin
      $error("[FAIL] zeroE asserted for zero result");
      errors++;
    end else begin
      $display("[PASS] zeroE asserted for zero result");
    end

    a = 32'h0000_0001; b = '0; ctrl = ZKNH_CTRL__SHA256SIG0;
    #1;
    if (zeroE !== 1'b0) begin
      $error("[FAIL] zeroE deasserted for non-zero result");
      errors++;
    end else begin
      $display("[PASS] zeroE deasserted for non-zero result");
    end

    // ---- Datapath: random operand pairs against the reference models ----
    for (int trial = 0; trial < 50; trial++) begin
      check_pair($urandom, $urandom, $sformatf("random[%0d]", trial));
    end
    $display("[PASS] 50 random operand pairs match the reference models");

    if (errors == 0)
      $display("\n=== ALL TESTS PASSED ===");
    else
      $display("\n=== %0d TEST(S) FAILED ===", errors);

    $finish;
  end

endmodule
