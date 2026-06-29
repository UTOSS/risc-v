`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/timescale.svh"

module Compressed_Decode
  ( input wire [15:0] instr_c // Compressed input instruction
  , output reg [31:0] instr_out // Expanded instruction
  , output reg is_illegal // Illegal or not implemented
  );

  wire [1:0] quadrant = instr_c[1:0];
  wire [2:0] c_funct3   = instr_c[15:13];

  // Common locations of registers in instruction format
  wire [4:0] rd_prime  = {2'b01, instr_c[4:2]};
  wire [4:0] rs1_prime = {2'b01, instr_c[9:7]};
  wire [4:0] rs2_prime = {2'b01, instr_c[4:2]};
  wire [4:0] rd_full  = instr_c[11:7];
  wire [4:0] rs1_full = instr_c[11:7];
  wire [4:0] rs2_full = instr_c[6:2];
  wire [4:0] c_shamt = instr_c[6:2];

  // Pre-compute immediates for each instruction format
  wire [11:0] ciw_imm     = {2'b00, instr_c[10:7], instr_c[12:11], instr_c[5], instr_c[6], 2'b00};
  wire [11:0] cl_cs_imm   = {5'b00000, instr_c[5], instr_c[12:10], instr_c[6], 2'b00};
  wire [11:0] ci_imm      = {{6{instr_c[12]}}, instr_c[12], instr_c[6:2]};
  wire [11:0] ci_sp_imm   = {{3{instr_c[12]}}, instr_c[4:3], instr_c[5], instr_c[2], instr_c[6], 4'b0000};
  wire [19:0] ci_lui_imm  = {{14{instr_c[12]}}, instr_c[12], instr_c[6:2]};
  wire [20:0] cj_imm      = {{9{instr_c[12]}}, instr_c[12], instr_c[8], instr_c[10:9], instr_c[6], instr_c[7], instr_c[2], instr_c[11], instr_c[5:3], 1'b0};
  wire [12:0] cb_imm      = {{4{instr_c[12]}}, instr_c[12], instr_c[6:5], instr_c[2], instr_c[11:10], instr_c[4:3], 1'b0};
  wire [11:0] ci_lwsp_imm = {4'b0000, instr_c[3:2], instr_c[12], instr_c[6:4], 2'b00};
  wire [11:0] css_imm     = {4'b0000, instr_c[8:7], instr_c[12:9], 2'b00};

  localparam bit [31:0] NOP = 32'h00000013;

  // Helpers to expand compressed instructions based on corresponding 32-bit instruction formats
  function automatic logic [31:0] build_r_instr
    ( input logic [6:0] funct7
    , input logic [4:0] rs2
    , input logic [4:0] rs1
    , input logic [2:0] funct3
    , input logic [4:0] rd
    , input logic [6:0] opcode
    );
    return {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] build_i_instr
    ( input logic [11:0] imm
    , input logic [4:0]  rs1
    , input logic [2:0]  funct3
    , input logic [4:0]  rd
    , input logic [6:0]  opcode
    );
    return {imm, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] build_i_shift_instr
    ( input logic [6:0] funct7
    , input logic [4:0] shamt
    , input logic [4:0] rs1
    , input logic [2:0] funct3
    , input logic [4:0] rd
    , input logic [6:0] opcode
    );
    return build_i_instr(.imm({funct7, shamt}), .rs1(rs1), .funct3(funct3), .rd(rd), .opcode(opcode));
  endfunction

  function automatic logic [31:0] build_s_instr
    ( input logic [11:0] imm
    , input logic [4:0]  rs2
    , input logic [4:0]  rs1
    , input logic [2:0]  funct3
    , input logic [6:0]  opcode
    );
    return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
  endfunction

  function automatic logic [31:0] build_b_instr
    ( input logic [12:0] imm
    , input logic [4:0]  rs2
    , input logic [4:0]  rs1
    , input logic [2:0]  funct3
    , input logic [6:0]  opcode
    );
    logic _unused = &{imm[0]};
    return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
  endfunction

  function automatic logic [31:0] build_u_instr
    ( input logic [19:0] imm
    , input logic [4:0]  rd
    , input logic [6:0]  opcode
    );
    return {imm, rd, opcode};
  endfunction

  function automatic logic [31:0] build_j_instr
    ( input logic [20:0] imm
    , input logic [4:0]  rd
    , input logic [6:0]  opcode
    );
    logic _unused = &{imm[0]};
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
  endfunction

  // Note: C.FLW, C.FSW, C.FLD, C.FSD, C.FLWSP, C.FLDSP, C.FSWSP, C.FSDSP should be added alongside future F/D extension support.
  always @(*) begin
    instr_out = NOP;
    is_illegal = 1'b0;

    case (quadrant) // Opcode
      2'b00: begin // Quadrant 0
        case (c_funct3)
          3'b000: begin
            instr_out = build_i_instr(.imm(ciw_imm), .rs1(5'd2), .funct3(3'b000), .rd(rd_prime), .opcode(IType_logic)); // C.ADDI4SPN
            if (ciw_imm == 12'b0) is_illegal = 1'b1;
          end
          3'b010: instr_out = build_i_instr(.imm(cl_cs_imm), .rs1(rs1_prime), .funct3(3'b010), .rd(rd_prime), .opcode(IType_load)); // C.LW
          3'b110: instr_out = build_s_instr(.imm(cl_cs_imm), .rs2(rs2_prime), .rs1(rs1_prime), .funct3(3'b010), .opcode(SType)); // C.SW
          default: is_illegal = 1'b1;
        endcase
      end

      2'b01: begin // Quadrant 1
        case (c_funct3)
          3'b000: instr_out = build_i_instr(.imm(ci_imm), .rs1(rd_full), .funct3(3'b000), .rd(rd_full), .opcode(IType_logic)); // C.ADDI
          // TODO C.JAL does not expand exactly to a base RVI instruction since the link address should be pc+2 instead of pc+4
          // Need to add support for offset of 2 bytes and e.g. preserve an is_compressed wire
          3'b001: instr_out = build_j_instr(.imm(cj_imm), .rd(5'd1), .opcode(JType)); // C.JAL
          3'b010: instr_out = build_i_instr(.imm(ci_imm), .rs1(5'd0), .funct3(3'b000), .rd(rd_full), .opcode(IType_logic)); // C.LI
          3'b011: begin
            case (instr_c[11:7])
              5'd2: begin
                instr_out = build_i_instr(.imm(ci_sp_imm), .rs1(5'd2), .funct3(3'b000), .rd(5'd2), .opcode(IType_logic)); // C.ADDI16SP
                if (ci_sp_imm == 12'b0) is_illegal = 1'b1;
              end
              default: begin
                instr_out = build_u_instr(.imm(ci_lui_imm), .rd(rd_full), .opcode(UType_lui)); // C.LUI
                if (ci_lui_imm == 20'b0 ) is_illegal = 1'b1;
              end
            endcase
          end
          3'b100: begin
            case (instr_c[11:10])
              2'b00: begin
                instr_out = build_i_shift_instr(.funct7(7'h00), .shamt(c_shamt), .rs1(rs1_prime), .funct3(3'b101), .rd(rs1_prime), .opcode(IType_logic)); // C.SRLI
                if (instr_c[12]) is_illegal = 1'b1;
              end
              2'b01: begin
                instr_out = build_i_shift_instr(.funct7(7'h20), .shamt(c_shamt), .rs1(rs1_prime), .funct3(3'b101), .rd(rs1_prime), .opcode(IType_logic)); // C.SRAI
                if (instr_c[12]) is_illegal = 1'b1;
              end
              2'b10: instr_out = build_i_instr(.imm(ci_imm), .rs1(rs1_prime), .funct3(3'b111), .rd(rs1_prime), .opcode(IType_logic)); // C.ANDI
              2'b11: begin
                if (instr_c[12]) is_illegal = 1'b1;
                case (instr_c[6:5])
                  2'b00: instr_out = build_r_instr(.funct7(7'h20), .rs2(rs2_prime), .rs1(rs1_prime), .funct3(3'b000), .rd(rs1_prime), .opcode(RType)); // C.SUB
                  2'b01: instr_out = build_r_instr(.funct7(7'h00), .rs2(rs2_prime), .rs1(rs1_prime), .funct3(3'b100), .rd(rs1_prime), .opcode(RType)); // C.XOR
                  2'b10: instr_out = build_r_instr(.funct7(7'h00), .rs2(rs2_prime), .rs1(rs1_prime), .funct3(3'b110), .rd(rs1_prime), .opcode(RType)); // C.OR
                  2'b11: instr_out = build_r_instr(.funct7(7'h00), .rs2(rs2_prime), .rs1(rs1_prime), .funct3(3'b111), .rd(rs1_prime), .opcode(RType)); // C.AND
                endcase
              end
              default: instr_out = NOP;
            endcase
          end
          3'b101: instr_out = build_j_instr(.imm(cj_imm), .rd(5'd0), .opcode(JType)); // C.J
          3'b110: instr_out = build_b_instr(.imm(cb_imm), .rs2(5'd0), .rs1(rs1_prime), .funct3(3'b000), .opcode(BType)); // C.BEQZ
          3'b111: instr_out = build_b_instr(.imm(cb_imm), .rs2(5'd0), .rs1(rs1_prime), .funct3(3'b001), .opcode(BType)); // C.BNEZ
        endcase
      end

      2'b10: begin // Quadrant 2
        case (c_funct3)
          3'b000: begin
            instr_out = build_i_shift_instr(.funct7(7'h00), .shamt(c_shamt), .rs1(rd_full), .funct3(3'b001), .rd(rd_full), .opcode(IType_logic)); // C.SLLI
            if (instr_c[12]) is_illegal = 1'b1;
          end
          3'b010: begin
            instr_out = build_i_instr(.imm(ci_lwsp_imm), .rs1(5'd2), .funct3(3'b010), .rd(rd_full), .opcode(IType_load)); // C.LWSP
            if (rd_full == 5'd0) is_illegal = 1'b1;
          end
          3'b100: begin
            case ({instr_c[12], instr_c[11:7] != 5'd0, instr_c[6:2] != 5'd0})
              3'b010:         instr_out = build_i_instr(.imm(12'd0), .rs1(rs1_full), .funct3(3'h0), .rd(5'd0), .opcode(IType_jalr)); // C.JR
              3'b011, 3'b001: instr_out = build_r_instr(.funct7(7'h00), .rs2(rs2_full), .rs1(5'd0), .funct3(3'h0), .rd(rd_full), .opcode(RType)); // C.MV
              3'b100:         instr_out = build_i_instr(.imm(12'h001), .rs1(5'd0), .funct3(3'h0), .rd(5'd0), .opcode(SYSTEM)); // C.EBREAK
              3'b110:         instr_out = build_i_instr(.imm(12'd0), .rs1(rs1_full), .funct3(3'h0), .rd(5'd1), .opcode(IType_jalr)); // C.JALR (TODO see note on C.JAL)
              3'b111, 3'b101: instr_out = build_r_instr(.funct7(7'h00), .rs2(rs2_full), .rs1(rd_full), .funct3(3'h0), .rd(rd_full), .opcode(RType)); // C.ADD
              default: is_illegal = 1'b1;
            endcase
          end
          3'b110: instr_out = build_s_instr(.imm(css_imm), .rs2(rs2_full), .rs1(5'd2), .funct3(3'b010), .opcode(SType)); // C.SWSP
          default: is_illegal = 1'b1;
        endcase
      end

      2'b11: is_illegal = 1'b1; // Not a compressed instruction
    endcase
  end

endmodule
