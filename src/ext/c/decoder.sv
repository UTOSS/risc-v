`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/headers/utils.svh"
`include "src/timescale.svh"

/* verilator lint_off DECLFILENAME */
module ext__c__decoder
/* verilator lint_on DECLFILENAME */
  ( input  wire [15:0] instr_c    // Compressed input instruction
  , output reg  [31:0] instr_out  // Expanded instruction
  , output reg         is_illegal // Illegal or not implemented
  );

  wire [1:0] quadrant = instr_c[1:0];
  wire [2:0] c_funct3 = instr_c[15:13];

  // Common register fields
  // - rd'/rs1'/rs2' are compressed 3-bit register indices mapped to x8..x15 (Table 37).
  // - full fields use the regular 5-bit register index directly.
  wire [4:0] rd_prime  = {2'b01, instr_c[4:2]};
  wire [4:0] rs1_prime = {2'b01, instr_c[9:7]};
  wire [4:0] rs2_prime = {2'b01, instr_c[4:2]};
  wire [4:0] rd_full   =         instr_c[11:7];
  wire [4:0] rs1_full  =         instr_c[11:7];
  wire [4:0] rs2_full  =         instr_c[6:2];
  wire [4:0] c_shamt   =         instr_c[6:2];

  // Decompressed immediates from compressed encodings.
  // References: Table 36 (formats), Section 28.3/28.4/28.5, Figure 3/4/5 bit listings.

  // as per "28.5.2. Integer Register-Immediate Operations" (C.ADDI4SPN, CIW format)
  //
  //                        [   11:10 |           9:6 |           5:4  |          3 |          2 |   1:0 ]
  wire [11:0] ciw_imm     = { 2'b00   , instr_c[10:7] , instr_c[12:11] , instr_c[5] , instr_c[6] , 2'b00 };

  // as per "28.3.2. Register-Based Loads and Stores" (CL/CS: C.LW, C.SW)
  //
  //                        [     11:7 |          6 |            5:3 |          2 |   1:0 ]
  wire [11:0] cl_cs_imm   = { 5'b00000 , instr_c[5] , instr_c[12:10] , instr_c[6] , 2'b00 };

  // as per "28.5.1/28.5.2" (CI format immediate used by C.ADDI/C.LI/C.ANDI)
  //
  //                        [             11:6 |           5 |          4:0 ]
  wire [11:0] ci_imm      = { {6{instr_c[12]}} , instr_c[12] , instr_c[6:2] };

  // as per "28.5.2. Integer Register-Immediate Operations" (C.ADDI16SP)
  //
  //                        [             11:9 |            8 |        7:6 |          5 |          4 |     3:0 ]
  wire [11:0] ci_sp_imm   = { {3{instr_c[12]}} , instr_c[4:3] , instr_c[5] , instr_c[2] , instr_c[6] , 4'b0000 };

  // as per "28.5.1. Integer Constant-Generation Instructions" (C.LUI)
  // even though nzimm in the figue in the section specifies ranges [17] and [16:12] we use
  // [17-12=5] and [16-12=4:12-12=0] since u-type instructions get 12 trailing eros as part of the
  // base ISA decode
  //
  //                        [              19:6 |           5 |          4:0 ]
  wire [19:0] ci_lui_imm  = { {14{instr_c[12]}} , instr_c[12] , instr_c[6:2] };

  // as per "28.4. Control Transfer Instructions" (CJ format: C.J/C.JAL)
  //
  //                        [            20:12 |          11 |        10  |           9:8 |         7  |         6  |         5  |           4 |          3:1 |    0 ]
  wire [20:0] cj_imm      = { {9{instr_c[12]}} , instr_c[12] , instr_c[8] , instr_c[10:9] , instr_c[6] , instr_c[7] , instr_c[2] , instr_c[11] , instr_c[5:3] , 1'b0 };

  // as per "28.4. Control Transfer Instructions" (CB format: C.BEQZ/C.BNEZ)
  //
  //                        [             12:9 |           8 |          7:6 |          5 |            4:3 |          2:1 |    0 ]
  wire [12:0] cb_imm      = { {4{instr_c[12]}} , instr_c[12] , instr_c[6:5] , instr_c[2] , instr_c[11:10] , instr_c[4:3] , 1'b0 };

  // as per "28.3.1. Stack-Pointer-Based Loads and Stores" (CI format: C.LWSP)
  //
  //                        [    11:8 |          7:6 |           5 |          4:2 |   1:0 ]
  wire [11:0] ci_lwsp_imm = { 4'b0000 , instr_c[3:2] , instr_c[12] , instr_c[6:4] , 2'b00 };

  // as per "28.3.1. Stack-Pointer-Based Loads and Stores" (CSS format: C.SWSP)
  //
  //                        [    11:8 |          7:6 |           5:2 |   1:0 ]
  wire [11:0] css_imm     = { 4'b0000 , instr_c[8:7] , instr_c[12:9] , 2'b00 };

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
    return build_i_instr
      ( .imm({funct7, shamt})
      , .rs1(rs1)
      , .funct3(funct3)
      , .rd(rd)
      , .opcode(opcode)
      );
  endfunction

  function automatic logic [31:0] build_s_instr
    /* verilator lint_off UNUSEDSIGNAL */ /* imm[0] is dropped to force 2-byte alignment */
    ( input logic [11:0] imm
    /* verilator lint_on UNUSEDSIGNAL */
    , input logic [4:0]  rs2
    , input logic [4:0]  rs1
    , input logic [2:0]  funct3
    , input logic [6:0]  opcode
    );
    return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
  endfunction

  function automatic logic [31:0] build_b_instr
    /* verilator lint_off UNUSEDSIGNAL */ /* imm[0] is dropped to force 2-byte alignment */
    ( input logic [12:0] imm
    /* verilator lint_on UNUSEDSIGNAL */
    , input logic [4:0]  rs2
    , input logic [4:0]  rs1
    , input logic [2:0]  funct3
    , input logic [6:0]  opcode
    );
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
    /* verilator lint_off UNUSEDSIGNAL */ /* imm[0] is dropped to force 2-byte alignment */
    ( input logic [20:0] imm
    /* verilator lint_on UNUSEDSIGNAL */
    , input logic [4:0]  rd
    , input logic [6:0]  opcode
    );
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
  endfunction

  // Docompressed instructions

  // as per Section 28.5.2. "Integer Constant-Generation / Register-Immediate Operations"
  wire instr_t dec_SRLI     = build_i_shift_instr( .funct7(7'h00) , .shamt(c_shamt) , .rs1(rs1_prime) , .funct3(3'b101) , .rd(rs1_prime) , .opcode(IType_logic) ); // srli rs1', rs1', shamt
  wire instr_t dec_SRAI     = build_i_shift_instr( .funct7(7'h20) , .shamt(c_shamt) , .rs1(rs1_prime) , .funct3(3'b101) , .rd(rs1_prime) , .opcode(IType_logic) ); // srai rs1', rs1', shamt
  wire instr_t dec_SLLI     = build_i_shift_instr( .funct7(7'h00) , .shamt(c_shamt) , .rs1(rd_full)   , .funct3(3'b001) , .rd(rd_full)   , .opcode(IType_logic) ); // slli rd, rd, shamt

  // as per Section 28.5.2. "Integer Constant-Generation / Register-Immediate Operations"
  wire instr_t dec_ANDI     = build_i_instr( .imm(ci_imm) , .rs1(rs1_prime) , .funct3(3'b111) , .rd(rs1_prime) , .opcode(IType_logic) ); // andi rs1', rs1', imm

  // as per Section 28.5.4. "Integer Register-Register Operations"
  wire instr_t dec_MV       = build_r_instr( .funct7(7'h00) , .rs2(rs2_full)  , .rs1(5'd0)      , .funct3(3'h000) , .rd(rd_full)   , .opcode(RType) ); // mv rd, rs2
  wire instr_t dec_ADD      = build_r_instr( .funct7(7'h00) , .rs2(rs2_full)  , .rs1(rd_full)   , .funct3(3'h000) , .rd(rd_full)   , .opcode(RType) ); // add rd, rd, rs2
  wire instr_t dec_SUB      = build_r_instr( .funct7(7'h20) , .rs2(rs2_prime) , .rs1(rs1_prime) , .funct3(3'b000) , .rd(rs1_prime) , .opcode(RType) ); // sub rs1', rs1', rs2'
  wire instr_t dec_XOR      = build_r_instr( .funct7(7'h00) , .rs2(rs2_prime) , .rs1(rs1_prime) , .funct3(3'b100) , .rd(rs1_prime) , .opcode(RType) ); // xor rs1', rs1', rs2'
  wire instr_t dec_OR       = build_r_instr( .funct7(7'h00) , .rs2(rs2_prime) , .rs1(rs1_prime) , .funct3(3'b110) , .rd(rs1_prime) , .opcode(RType) ); // or rs1', rs1', rs2'
  wire instr_t dec_AND      = build_r_instr( .funct7(7'h00) , .rs2(rs2_prime) , .rs1(rs1_prime) , .funct3(3'b111) , .rd(rs1_prime) , .opcode(RType) ); // and rs1', rs1', rs2'

  // as per Section 28.3.1. "Stack-Pointer-Based Loads and Stores"
  wire instr_t dec_SWSP     = build_s_instr( .imm(css_imm) , .rs2(rs2_full) , .rs1(5'd2) , .funct3(3'b010) , .opcode(SType) ); // sw rs2, offset(sp)

  // as per Section 28.3.1. "Stack-Pointer-Based Loads and Stores"
  wire instr_t dec_LWSP     = build_i_instr( .imm(ci_lwsp_imm) , .rs1(5'd2) , .funct3(3'b010) , .rd(rd_full) , .opcode(IType_load) ); // lw rd, offset(sp)

  // as per Section 28.3.2. "Register-Based Loads and Stores"
  wire instr_t dec_SW       = build_s_instr( .imm(cl_cs_imm) , .rs2(rs2_prime) , .rs1(rs1_prime) , .funct3(3'b010) , .opcode(SType) ); // sw rs2′, offset(rs1′)

  // as per Section 28.3.2. "Register-Based Loads and Stores"
  wire instr_t dec_LW       = build_i_instr( .imm(cl_cs_imm) , .rs1(rs1_prime) , .funct3(3'b010) , .rd(rd_prime) , .opcode(IType_load) ); // lw rd′, offset(rs1′)

  // as per Section 28.4. "Control Transfer Instructions"
  wire instr_t dec_JAL      = build_j_instr( .imm(cj_imm), .rd(5'd1) , .opcode(JType) ); // jal x1, offset
  wire instr_t dec_J        = build_j_instr( .imm(cj_imm), .rd(5'd0) , .opcode(JType) ); // jal x0, offset

  // as per Section 28.4. "Control Transfer Instructions"
  wire instr_t dec_JALR     = build_i_instr( .imm(12'd0) , .rs1(rs1_full) , .funct3(3'h000) , .rd(5'd1) , .opcode(IType_jalr) ); // jalr x1, 0(rs1)

  // as per Section 28.4. "Control Transfer Instructions"
  wire instr_t dec_BEQZ     = build_b_instr( .imm(cb_imm) , .rs2(5'd0) , .rs1(rs1_prime) , .funct3(3'b000) , .opcode(BType) ); // beq rs1', x0, offset
  wire instr_t dec_BNEZ     = build_b_instr( .imm(cb_imm) , .rs2(5'd0) , .rs1(rs1_prime) , .funct3(3'b001) , .opcode(BType) ); // bne rs1', x0, offset

  // as per Section 28.5.1. "Integer Constant-Generation Instructions"
  wire instr_t dec_LUI      = build_u_instr( .imm(ci_lui_imm) , .rd(rd_full) , .opcode(UType_lui) ); // lui rd, imm

  // as per Section 28.5.1. "Integer Constant-Generation Instructions"
  wire instr_t dec_LI       = build_i_instr( .imm(ci_imm) , .rs1(5'd0)    , .funct3(3'b000) , .rd(rd_full) , .opcode(IType_logic) ); // addi rd, x0, imm
  wire instr_t dec_ADDI     = build_i_instr( .imm(ci_imm) , .rs1(rd_full) , .funct3(3'b000) , .rd(rd_full) , .opcode(IType_logic) ); // addi rd, rd, imm

  // as per Section 28.5.2. "Integer Register-Immediate Operations"
  wire instr_t dec_ADDI4SPN = build_i_instr( .imm(ciw_imm)   , .rs1(5'd2) , .funct3(3'b000) , .rd(rd_prime)  , .opcode(IType_logic) ); // addi rd′, x2, nzuimm[9:2]
  wire instr_t dec_ADDI16SP = build_i_instr( .imm(ci_sp_imm) , .rs1(5'd2) , .funct3(3'b000) , .rd(5'd2)      , .opcode(IType_logic) ); // addi x2, x2, nzimm[9:4]

  // as per Section 28.5.6. "Breakpoint Instruction"
  wire instr_t dec_EBREAK   = build_i_instr( .imm(12'h001) , .rs1(5'd0) , .funct3(3'h000) , .rd(5'd0) , .opcode(SYSTEM)      ); // ebreak

  // Note: C.FLW, C.FSW, C.FLD, C.FSD, C.FLWSP, C.FLDSP, C.FSWSP, C.FSDSP should be added alongside future F/D extension support.
  always_comb
    case (quadrant)
      2'b00:
        // Quadrant 0 (Figure 3. Instruction listing for RVC, Quadrant 0)

        case (c_funct3)
          3'b000:             {instr_out, is_illegal} = {dec_ADDI4SPN    , ciw_imm == 12'b0   };
          3'b010:             {instr_out, is_illegal} = {dec_LW          , `FALSE             };
          3'b110:             {instr_out, is_illegal} = {dec_SW          , `FALSE             };

          // RV32C subset implemented here: floating-point and RV64C opcodes are treated as illegal.
          default:            {instr_out, is_illegal} = {instr_t'(0)     , `TRUE             };
        endcase

      2'b01:
        // Quadrant 1 (Figure 4. Instruction listing for RVC, Quadrant 1)

        case (c_funct3)
          3'b000:             {instr_out, is_illegal} = {dec_ADDI        , `FALSE             };
          3'b001:
            // TODO: C.JAL does not expand exactly to a base RVI instruction since the link address
            // should be pc+2 instead of pc+4 Need to add support for offset of 2 bytes and e.g.
            // preserve an is_compressed wire
                              {instr_out, is_illegal} = {dec_JAL         , `FALSE             };
          3'b010:             {instr_out, is_illegal} = {dec_LI          , `FALSE             };
          3'b011:
            case (instr_c[11:7])
              5'd2:           {instr_out, is_illegal} = {dec_ADDI16SP    , ci_sp_imm == 12'b0 };
              // TODO: handle 5'd0 as per 28.1.5.1 -- "The code points with rd=x0 and imm≠0 are
              // HINTs."
              default:        {instr_out, is_illegal} = {dec_LUI         , ci_lui_imm == 20'b0};
            endcase
          3'b100:
            case (instr_c[11:10])
              2'b00:          {instr_out, is_illegal} = {dec_SRLI        , instr_c[12]        };
              2'b01:          {instr_out, is_illegal} = {dec_SRAI        , instr_c[12]        };
              2'b10:          {instr_out, is_illegal} = {dec_ANDI        , `FALSE             };
              2'b11:
                case (instr_c[6:5])
                  2'b00:      {instr_out, is_illegal} = {dec_SUB         , instr_c[12]        };
                  2'b01:      {instr_out, is_illegal} = {dec_XOR         , instr_c[12]        };
                  2'b10:      {instr_out, is_illegal} = {dec_OR          , instr_c[12]        };
                  2'b11:      {instr_out, is_illegal} = {dec_AND         , instr_c[12]        };
                endcase
              default:        {instr_out, is_illegal} = {instr_t'(NOP)   , `FALSE             };
            endcase
          3'b101:             {instr_out, is_illegal} = {dec_J           , `FALSE             };
          3'b110:             {instr_out, is_illegal} = {dec_BEQZ        , `FALSE             };
          3'b111:             {instr_out, is_illegal} = {dec_BNEZ        , `FALSE             };
        endcase

      2'b10:
        // Quadrant 2 (Figure 5. Instruction listing for RVC, Quadrant 2)

        case (c_funct3)
          3'b000:             {instr_out, is_illegal} = {dec_SLLI        , instr_c[12]        };
          3'b010:             {instr_out, is_illegal} = {dec_LWSP        , rd_full == 5'd0    };
          3'b100:
            // Figure 5 CR encodings: JR/MV/EBREAK/JALR/ADD are selected by {bit12, rs1!=0, rs2!=0}.
            case ({instr_c[12], instr_c[11:7] != 5'd0, instr_c[6:2] != 5'd0})
              3'b010:         {instr_out, is_illegal} = {dec_J           , `FALSE             };
              3'b011, 3'b001: {instr_out, is_illegal} = {dec_MV          , `FALSE             };
              3'b100:         {instr_out, is_illegal} = {dec_EBREAK      , `FALSE             };
              3'b110:         {instr_out, is_illegal} = {dec_JALR        , `FALSE             };
              3'b111, 3'b101: {instr_out, is_illegal} = {dec_ADD         , `FALSE             };
              default:        {instr_out, is_illegal} = {instr_t'(0)     , `TRUE              };
            endcase
          3'b110:             {instr_out, is_illegal} = {dec_SWSP        , `FALSE             };
          default:            {instr_out, is_illegal} = {instr_t'(0)     , `TRUE              };
        endcase

      // Per Table 39, quadrant 3 is >16b and not an RVC opcode.
      2'b11:                  {instr_out, is_illegal} = {instr_t'(0)     , `TRUE              };
    endcase

endmodule
