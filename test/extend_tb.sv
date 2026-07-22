`include "src/timescale.svh"

`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "test/utils.svh"

module extend_tb;

  instr_t  instr;
  opcode_t opcode;
  imm_t    imm_ext;

  extend uut
    ( .instr   ( instr[31:7] )
    , .opcode  ( opcode      )
    , .imm_ext ( imm_ext     )
    );

  task automatic check_imm
    ( input opcode_t test_opcode
    , input instr_t  test_instr
    , input imm_t    expected
    );
    opcode = test_opcode;
    instr = test_instr;
    #1;
    assert (imm_ext == expected)
      else $fatal(1, "opcode=%b instr=%h: expected imm_ext=%h, got %h", opcode, instr, expected, imm_ext);
  endtask

  initial begin
    // I-type: positive and negative immediates.
    check_imm(OPCODE_OP_IMM, 32'h1230_0093, 32'h0000_0123);
    check_imm(OPCODE_LOAD, 32'hfff0_2083, 32'hffff_ffff);
    check_imm(OPCODE_JALR, 32'h8000_0067, 32'hffff_f800);

    // S-type: immediate bits are split between instr[31:25] and instr[11:7].
    check_imm(OPCODE_STORE, 32'h7e00_0fa3, 32'h0000_07ff);
    check_imm(OPCODE_STORE, 32'h8000_0023, 32'hffff_f800);

    // B-type: immediate is sign-extended and its least-significant bit is zero.
    check_imm(OPCODE_BRANCH, 32'h7e00_0fe3, 32'h0000_0ffe);
    check_imm(OPCODE_BRANCH, 32'h8000_0063, 32'hffff_f000);

    // J-type: immediate is sign-extended and its least-significant bit is zero.
    check_imm(OPCODE_JAL, 32'h7ff0_00ef, 32'h0000_0ffe);
    check_imm(OPCODE_JAL, 32'h8000_006f, 32'hfff0_0000);

    // U-type: the upper 20 instruction bits are preserved.
    check_imm(OPCODE_LUI, 32'habcde_0b7, 32'habcde_000);
    check_imm(OPCODE_AUIPC, 32'h12345_097, 32'h12345_000);

    // Opcodes without an immediate produce zero.
    check_imm(OPCODE_OP, 32'hffff_ffff, 32'b0);
  end

  `SETUP_VCD_DUMP(extend_tb)

endmodule
