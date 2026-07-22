`timescale 1ns/1ns
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"
`include "test/utils.svh"

module zbs_decoder_tb;

  import ext__b__types::*;

  logic [31:0] instr;
  wire opcode_t opcode;
  wire [3:0] alu_control;
  wire imm_t imm_ext;
  wire [2:0] funct3;
  wire [4:0] rd;
  wire [4:0] rs1;
  wire [4:0] rs2;
  wire b_alu_control_t b_alu_control;

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
    , .opcode     ( opcode     )
    , .ALUControl ( alu_control )
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
    assert (alu_control == ALU_CONTROL_ADD) else
      $fatal(1, "base decode sanity check failed: got %0h", alu_control);

`ifdef UTOSS_RISCV_ENABLE_B_EXT
    instr = make_r_zbs(7'b0010100, 3'b001, 5'd3, 5'd2, 5'd1); // bset
    #1;
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
