`include "src/timescale.svh"

`include "test/utils.svh"

`include "src/headers/types.svh"
`include "src/ext/a/types.svh"

module a_decoder_tb;

  import ext__a__types::*;

  opcode_t    opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  reg_t       rs2;

  a_op_t a_op;
  logic  aq;
  logic  rl;
  logic  is_illegal;

  ext__a__decoder uut
    ( .opcode     ( opcode     )
    , .funct3     ( funct3     )
    , .funct7     ( funct7     )
    , .rs2        ( rs2        )
    , .a_op       ( a_op       )
    , .aq         ( aq         )
    , .rl         ( rl         )
    , .is_illegal ( is_illegal )
    );

  localparam bit [2:0] FUNCT3__W = 3'b010; // RV32A word variants
  localparam bit [2:0] FUNCT3__D = 3'b011; // RV64A doubleword variants

  // drives an A-extension encoding and lets it settle; note how funct7 is assembled from
  // {funct5, aq, rl} rather than being a single field
  task automatic drive
    ( input bit [4:0] funct5
    , input bit aq_bit
    , input bit rl_bit
    , input bit [2:0] width
    , input bit [4:0] rs2_field
    );
    opcode = OPCODE_AMO;
    funct3 = width;
    funct7 = {funct5, aq_bit, rl_bit};
    rs2    = rs2_field;
    #10;
  endtask

  // shorthand for the common case: word-wide, no ordering bits, rs2 = x1
  task automatic drive_w(input bit [4:0] funct5);
    drive(funct5, 1'b0, 1'b0, FUNCT3__W, 5'd1);
  endtask

  initial begin

    // ---------------------------------------------------------------------------------------
    // every RV32A operation decodes to its own a_op
    // ---------------------------------------------------------------------------------------

    // lr.w has no second operand -- rs2 must be zero
    drive(5'b00010, 1'b0, 1'b0, FUNCT3__W, 5'd0);
    `assert_equal(a_op, A_OP__LR)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b00011);
    `assert_equal(a_op, A_OP__SC)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b00001);
    `assert_equal(a_op, A_OP__AMOSWAP)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b00000);
    `assert_equal(a_op, A_OP__AMOADD)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b00100);
    `assert_equal(a_op, A_OP__AMOXOR)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b01100);
    `assert_equal(a_op, A_OP__AMOAND)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b01000);
    `assert_equal(a_op, A_OP__AMOOR)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b10000);
    `assert_equal(a_op, A_OP__AMOMIN)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b10100);
    `assert_equal(a_op, A_OP__AMOMAX)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b11000);
    `assert_equal(a_op, A_OP__AMOMINU)
    `assert_equal(is_illegal, `FALSE)

    drive_w(5'b11100);
    `assert_equal(a_op, A_OP__AMOMAXU)
    `assert_equal(is_illegal, `FALSE)

    // ---------------------------------------------------------------------------------------
    // aq/rl are extracted from funct7[1:0] and must not disturb operation selection
    // ---------------------------------------------------------------------------------------

    drive(5'b00000, 1'b0, 1'b0, FUNCT3__W, 5'd1);
    `assert_equal(a_op, A_OP__AMOADD)
    `assert_equal(aq, 1'b0)
    `assert_equal(rl, 1'b0)

    drive(5'b00000, 1'b1, 1'b0, FUNCT3__W, 5'd1);
    `assert_equal(a_op, A_OP__AMOADD)
    `assert_equal(aq, 1'b1)
    `assert_equal(rl, 1'b0)

    drive(5'b00000, 1'b0, 1'b1, FUNCT3__W, 5'd1);
    `assert_equal(a_op, A_OP__AMOADD)
    `assert_equal(aq, 1'b0)
    `assert_equal(rl, 1'b1)

    // amoadd.w.aqrl -- the sequentially consistent form
    drive(5'b00000, 1'b1, 1'b1, FUNCT3__W, 5'd1);
    `assert_equal(a_op, A_OP__AMOADD)
    `assert_equal(aq, 1'b1)
    `assert_equal(rl, 1'b1)

    // same check on lr.w, whose funct5 differs -- guards against a decoder that compares the whole
    // funct7 and so only works when aq = rl = 0
    drive(5'b00010, 1'b1, 1'b1, FUNCT3__W, 5'd0);
    `assert_equal(a_op, A_OP__LR)
    `assert_equal(aq, 1'b1)
    `assert_equal(rl, 1'b1)

    // ---------------------------------------------------------------------------------------
    // encodings we must reject
    // ---------------------------------------------------------------------------------------

    // `.d` variants are RV64A only
    drive(5'b00000, 1'b0, 1'b0, FUNCT3__D, 5'd1);
    `assert_equal(a_op, A_OP__NONE)
    `assert_equal(is_illegal, `TRUE)

    // funct3 outside {010, 011} is not an atomic width at all
    drive(5'b00000, 1'b0, 1'b0, 3'b000, 5'd1);
    `assert_equal(a_op, A_OP__NONE)
    `assert_equal(is_illegal, `TRUE)

    // funct5 = 11111 is not allocated
    drive_w(5'b11111);
    `assert_equal(a_op, A_OP__NONE)
    `assert_equal(is_illegal, `TRUE)

    // lr.w with rs2 != 0 is reserved
    drive(5'b00010, 1'b0, 1'b0, FUNCT3__W, 5'd7);
    `assert_equal(a_op, A_OP__NONE)
    `assert_equal(is_illegal, `TRUE)

    // ---------------------------------------------------------------------------------------
    // non-atomic opcodes must be left alone
    //
    // `slt rd, rs1, rs2` is bit-identical to `amoadd.w rd, rs2, (rs1)` apart from the opcode
    // (funct3 = 010, funct7 = 0000000), so this catches a decoder that forgets to gate on the
    // opcode
    // ---------------------------------------------------------------------------------------

    opcode = OPCODE_OP;
    funct3 = 3'b010;
    funct7 = 7'b0000000;
    rs2    = 5'd1;
    #10;
    `assert_equal(a_op, A_OP__NONE)
    `assert_equal(is_illegal, `FALSE)

    // an R-type funct7 must never be mistaken for acquire/release; `sub` is funct7 = 0100000, so
    // funct7[1:0] happens to be 00 -- use a shift-right-arithmetic-like pattern with the low bits
    // set to make the check meaningful
    opcode = OPCODE_OP;
    funct3 = 3'b101;
    funct7 = 7'b0000011;
    rs2    = 5'd1;
    #10;
    `assert_equal(a_op, A_OP__NONE)
    `assert_equal(aq, 1'b0)
    `assert_equal(rl, 1'b0)
    `assert_equal(is_illegal, `FALSE)

    // a plain load shares nothing with an atomic but is the opcode most likely to be confused with
    // one in the memory stage
    opcode = OPCODE_LOAD;
    funct3 = FUNCT3__W;
    funct7 = 7'b0000000;
    rs2    = 5'd0;
    #10;
    `assert_equal(a_op, A_OP__NONE)
    `assert_equal(is_illegal, `FALSE)

    $display("a_decoder_tb: all assertions passed");
    $finish;
  end

  `SETUP_VCD_DUMP(a_decoder_tb)

endmodule
