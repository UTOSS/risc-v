`include "src/timescale.svh"

`include "test/utils.svh"

module mul_tb;

  logic        clk;
  logic        rst_n;
  logic        start_i;
  logic [31:0] rs1_i;
  logic [31:0] rs2_i;
  logic [1:0]  op_i;
  logic [31:0] result_o;
  logic        ready_o;

  localparam logic [1:0] MUL    = 2'b00;
  localparam logic [1:0] MULH   = 2'b01;
  localparam logic [1:0] MULHSU = 2'b10;
  localparam logic [1:0] MULHU  = 2'b11;

  mul uut
    ( .clk      ( clk      )
    , .rst_n    ( rst_n    )
    , .start_i  ( start_i  )
    , .rs1_i    ( rs1_i    )
    , .rs2_i    ( rs2_i    )
    , .op_i     ( op_i     )
    , .result_o ( result_o )
    , .ready_o  ( ready_o  )
    );

  initial begin
    clk = 0; rst_n = 1; start_i = 1;

    // ready_o is combinational, asserted same cycle as start_i
    #1;
    `assert_equal(ready_o, 1'b1)

    // --- MUL: low 32 bits (sign-agnostic) ---
    // 7 * 6 = 42
    op_i = MUL; rs1_i = 32'd7; rs2_i = 32'd6; #1;
    `assert_equal(result_o, 32'h0000_002A)

    // 0x10000 * 0x10000 = 0x1_0000_0000 -> low 32 = 0
    op_i = MUL; rs1_i = 32'h0001_0000; rs2_i = 32'h0001_0000; #1;
    `assert_equal(result_o, 32'h0000_0000)

    // --- MULH: high 32, signed x signed ---
    // 2^30 * 2^30 = 2^60 = 0x1000_0000_0000_0000 -> high = 0x1000_0000
    op_i = MULH; rs1_i = 32'h4000_0000; rs2_i = 32'h4000_0000; #1;
    `assert_equal(result_o, 32'h1000_0000)

    // (-1) * 2 = -2 = 0xFFFF_FFFF_FFFF_FFFE -> high = 0xFFFF_FFFF
    op_i = MULH; rs1_i = 32'hFFFF_FFFF; rs2_i = 32'd2; #1;
    `assert_equal(result_o, 32'hFFFF_FFFF)

    // --- The three-way sign test: same bits, three ops, three results ---
    // MULH:   (-1) * (-1) = 1                 -> high = 0x0000_0000
    op_i = MULH;   rs1_i = 32'hFFFF_FFFF; rs2_i = 32'hFFFF_FFFF; #1;
    `assert_equal(result_o, 32'h0000_0000)

    // MULHU:  0xFFFFFFFF * 0xFFFFFFFF = 0xFFFF_FFFE_0000_0001 -> high = 0xFFFF_FFFE
    op_i = MULHU;  rs1_i = 32'hFFFF_FFFF; rs2_i = 32'hFFFF_FFFF; #1;
    `assert_equal(result_o, 32'hFFFF_FFFE)

    // MULHSU: (-1) * 4294967295 = -4294967295 = 0xFFFF_FFFF_0000_0001 -> high = 0xFFFF_FFFF
    op_i = MULHSU; rs1_i = 32'hFFFF_FFFF; rs2_i = 32'hFFFF_FFFF; #1;
    `assert_equal(result_o, 32'hFFFF_FFFF)

    $display("All mul_tb tests passed");
  end

  `SETUP_VCD_DUMP(mul_tb)

endmodule
