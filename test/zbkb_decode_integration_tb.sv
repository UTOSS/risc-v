`include "test/utils.svh"
`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

module zbkb_decode_integration_tb;

  import ext__b__types::*;

  logic [2:0] funct3;
  logic [6:0] funct7;
  opcode_t    opcode;
  reg_t       rd;
  reg_t       rs2;

  b_alu_control_t b_alu_control;

  logic [31:0] a, b;
  logic [31:0] out;
/* verilator lint_off UNUSEDSIGNAL */
  logic        zeroE;
/* verilator lint_on UNUSEDSIGNAL */

  ext__b__decoder u_decoder
    ( .funct3        ( funct3        )
    , .funct7        ( funct7        )
    , .opcode        ( opcode        )
    , .rd            ( rd            )
    , .rs2           ( rs2           )
    , .b_alu_control ( b_alu_control )
    );

  zbkb u_zbkb
    ( .a             ( a             )
    , .b             ( b             )
    , .b_alu_control ( b_alu_control )
    , .out           ( out           )
    , .zeroE         ( zeroE         )
    );

  initial begin
    rd = '0;
    // ---- PACK: opcode=OP, funct7=PACK_GROUP, funct3=100, rs2!=0 ----
    opcode = opcode_t'(7'b0110011);
    funct7 = 7'b0000100;
    funct3 = 3'b100;
    rs2    = 5'b00001;
    a = 32'h0000_1234; b = 32'h0000_5678;
    #1;
    assert (b_alu_control == B_ALU_CTRL__PACK) else $fatal(1, "decode: expected PACK");
    assert (out == 32'h5678_1234) else $fatal(1, "pack integration: got %h", out);

    // ---- PACKH ----
    funct3 = 3'b111;
    a = 32'hAAAA_AA12; b = 32'hBBBB_BB34;
    #1;
    assert (b_alu_control == B_ALU_CTRL__PACKH) else $fatal(1, "decode: expected PACKH");
    assert (out == 32'h0000_3412) else $fatal(1, "packh integration: got %h", out);

    // ---- BREV8: opcode=OP_IMM, funct7=REV8_BREV8, funct3=101, rs2=00111 ----
    opcode = opcode_t'(7'b0010011);
    funct7 = 7'b0110100;
    funct3 = 3'b101;
    rs2    = 5'b00111;
    a = 32'h1234_5678;
    #1;
    assert (b_alu_control == B_ALU_CTRL__BREV8) else $fatal(1, "decode: expected BREV8");
    assert (out == 32'h482C_6A1E) else $fatal(1, "brev8 integration: got %h", out);

    // ---- REV8: same funct7, different rs2 ----
    rs2 = 5'b11000;
    #1;
    assert (b_alu_control == B_ALU_CTRL__REV8) else $fatal(1, "decode: expected REV8");
    assert (out == 32'h7856_3412) else $fatal(1, "rev8 integration: got %h", out);

    // ---- ZIP ----
    funct7 = 7'b0000100;
    funct3 = 3'b001;
    rs2    = 5'b01111;
    a = 32'h0000_FFFF;
    #1;
    assert (b_alu_control == B_ALU_CTRL__ZIP) else $fatal(1, "decode: expected ZIP");
    assert (out == 32'h5555_5555) else $fatal(1, "zip integration: got %h", out);

    // ---- UNZIP ----
    funct3 = 3'b101;
    a = 32'h5555_5555;
    #1;
    assert (b_alu_control == B_ALU_CTRL__UNZIP) else $fatal(1, "decode: expected UNZIP");
    assert (out == 32'h0000_FFFF) else $fatal(1, "unzip integration: got %h", out);

    // ---- Sanity: unrelated instruction should decode to NONE ----
    opcode = opcode_t'(7'b0000011); // LOAD, unrelated to B-ext entirely
    #1;
    assert (b_alu_control == B_ALU_CTRL__NONE) else $fatal(1, "decode: expected NONE for unrelated opcode");

    $display("=== ALL DECODE+ZBKB INTEGRATION TESTS PASSED ===");
  end

  `SETUP_VCD_DUMP(zbkb_decode_integration_tb)

endmodule
