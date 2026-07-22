`timescale 1ns/1ns
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"
`include "test/utils.svh"

module zbs_decoder_tb;

  import ext__b__types::*;

  logic [31:0] instr;
  logic [3:0] alu_control;
  opcode_t opcode;
  imm_t imm_ext;
  logic [2:0] funct3;
  logic [4:0] rd;
  logic [4:0] rs1;
  logic [4:0] rs2;
`ifdef UTOSS_RISCV_ENABLE_B_EXT
  b_alu_control_t b_alu_control;
`endif

  function automatic logic [31:0] make_r_zbs
    ( input logic [6:0] funct7_i
    , input logic [2:0] funct3_i
    , input logic [4:0] rs2_i
    , input logic [4:0] rs1_i
    , input logic [4:0] rd_i
    );
    return {funct7_i, rs2_i, rs1_i, funct3_i, rd_i, 7'b0110011};
  endfunction

  function automatic logic [31:0] make_i_zbs
    ( input logic [6:0] funct7_i
    , input logic [4:0] shamt_i
    , input logic [4:0] rs1_i
    , input logic [4:0] rd_i
    , input logic [2:0] funct3_i
    );
    return {funct7_i, shamt_i, rs1_i, funct3_i, rd_i, 7'b0010011};
  endfunction

  Instruction_Decode uut
    ( .instr      ( instr      )
    , .ALUControl ( alu_control )
    , .opcode     ( opcode     )
    , .imm_ext    ( imm_ext    )
    , .funct3     ( funct3     )
    , .rd         ( rd         )
    , .rs1        ( rs1        )
    , .rs2        ( rs2        )
`ifdef UTOSS_RISCV_ENABLE_B_EXT
    , .b_alu_control ( b_alu_control )
`endif
    );

  initial begin
    instr = 32'd0;
    #1;

    instr = 32'h00000013; // addi x0, x0, 0
    #1;
    assert (opcode == OPCODE_OP_IMM) else
      $fatal(1, "opcode decode failed for addi: got %0h", opcode);
    assert (alu_control == ALU_CONTROL_ADD) else
      $fatal(1, "base decode sanity check failed: got %0h", alu_control);
    assert (imm_ext == 32'h0) else
      $fatal(1, "imm decode failed for addi: got %0h", imm_ext);
    assert (funct3 == 3'b000) else
      $fatal(1, "funct3 decode failed for addi: got %0h", funct3);
    assert (rd == 5'h0) else
      $fatal(1, "rd decode failed for addi: got %0h", rd);
    assert (rs1 == 5'h0) else
      $fatal(1, "rs1 decode failed for addi: got %0h", rs1);
    assert (rs2 == 5'h0) else
      $fatal(1, "rs2 decode failed for addi: got %0h", rs2);

`ifdef UTOSS_RISCV_ENABLE_B_EXT
    instr = make_r_zbs(7'b0010100, 3'b001, 5'd3, 5'd2, 5'd1); // bset
    #1;
    assert (opcode == OPCODE_OP) else
      $fatal(1, "opcode decode failed for bset: got %0h", opcode);
    assert (funct3 == 3'b001) else
      $fatal(1, "funct3 decode failed for bset: got %0h", funct3);
    assert (rd == 5'd1) else
      $fatal(1, "rd decode failed for bset: got %0h", rd);
    assert (rs1 == 5'd2) else
      $fatal(1, "rs1 decode failed for bset: got %0h", rs1);
    assert (rs2 == 5'd3) else
      $fatal(1, "rs2 decode failed for bset: got %0h", rs2);
    assert (b_alu_control == B_ALU_CTRL__BSET) else
      $fatal(1, "bset decode failed: got %0h", b_alu_control);

    instr = make_r_zbs(7'b0100100, 3'b001, 5'd3, 5'd2, 5'd1); // bclr
    #1;
    assert (b_alu_control == B_ALU_CTRL__BCLR) else
      $fatal(1, "bclr decode failed: got %0h", b_alu_control);

    instr = make_r_zbs(7'b0110100, 3'b001, 5'd3, 5'd2, 5'd1); // binv
    #1;
    assert (b_alu_control == B_ALU_CTRL__BINV) else
      $fatal(1, "binv decode failed: got %0h", b_alu_control);

    instr = make_r_zbs(7'b0100100, 3'b101, 5'd3, 5'd2, 5'd1); // bext
    #1;
    assert (b_alu_control == B_ALU_CTRL__BEXT) else
      $fatal(1, "bext decode failed: got %0h", b_alu_control);

    instr = make_i_zbs(7'b0010100, 5'd3, 5'd2, 5'd1, 3'b001); // bseti
    #1;
    assert (opcode == OPCODE_OP_IMM) else
      $fatal(1, "opcode decode failed for bseti: got %0h", opcode);
    assert (b_alu_control == B_ALU_CTRL__BSET) else
      $fatal(1, "bseti decode failed: got %0h", b_alu_control);

    instr = make_i_zbs(7'b0100100, 5'd3, 5'd2, 5'd1, 3'b001); // bclri
    #1;
    assert (b_alu_control == B_ALU_CTRL__BCLR) else
      $fatal(1, "bclri decode failed: got %0h", b_alu_control);

    instr = make_i_zbs(7'b0110100, 5'd3, 5'd2, 5'd1, 3'b001); // binvi
    #1;
    assert (b_alu_control == B_ALU_CTRL__BINV) else
      $fatal(1, "binvi decode failed: got %0h", b_alu_control);

    instr = make_i_zbs(7'b0100100, 5'd3, 5'd2, 5'd1, 3'b101); // bexti
    #1;
    assert (b_alu_control == B_ALU_CTRL__BEXT) else
      $fatal(1, "bexti decode failed: got %0h", b_alu_control);
`else
    $display("B extension is disabled; Zbs integration checks were skipped.");
`endif

    $display("Zbs decode tests passed!");
    $finish;
  end

  `SETUP_VCD_DUMP(zbs_decoder_tb)

endmodule
