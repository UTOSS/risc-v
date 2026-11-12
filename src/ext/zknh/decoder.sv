`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zknh/types.svh"

/* verilator lint_off DECLFILENAME */
module ext__zknh__decoder
/* verilator lint_on DECLFILENAME */
  ( input [2:0] funct3
  , input [6:0] funct7
  , input opcode_t opcode
  , input reg_t rs2
  , output ext__zknh__types::zknh_control_t zknh_control
  );

  import ext__zknh__types::*;

  // The SHA2-256 instructions are encoded as OP-IMM with funct3 = 001 and
  // funct7 = 0001000; the rs2 field selects the instruction.
  localparam bit [2:0] FUNCT3__SHA256 = 3'b001;
  localparam bit [6:0] FUNCT7__SHA256 = 7'b0001000;

  // The SHA2-512 instructions available on RV32 are encoded as OP with
  // funct3 = 000; the funct7 field selects the instruction and rs2 is an operand.
  localparam bit [2:0] FUNCT3__SHA512 = 3'b000;
  localparam bit [6:0] FUNCT7__SHA512SUM0R = 7'b0101000;
  localparam bit [6:0] FUNCT7__SHA512SUM1R = 7'b0101001;
  localparam bit [6:0] FUNCT7__SHA512SIG0L = 7'b0101010;
  localparam bit [6:0] FUNCT7__SHA512SIG1L = 7'b0101011;
  localparam bit [6:0] FUNCT7__SHA512SIG0H = 7'b0101110;
  localparam bit [6:0] FUNCT7__SHA512SIG1H = 7'b0101111;

  always_comb
    if (opcode == OPCODE_OP_IMM && funct3 == FUNCT3__SHA256 && funct7 == FUNCT7__SHA256)
      case (rs2)
        5'b00000: zknh_control = ZKNH_CTRL__SHA256SUM0;
        5'b00001: zknh_control = ZKNH_CTRL__SHA256SUM1;
        5'b00010: zknh_control = ZKNH_CTRL__SHA256SIG0;
        5'b00011: zknh_control = ZKNH_CTRL__SHA256SIG1;
        default:  zknh_control = ZKNH_CTRL__NONE;
      endcase
    else if (opcode == OPCODE_OP && funct3 == FUNCT3__SHA512)
      case (funct7)
        FUNCT7__SHA512SUM0R: zknh_control = ZKNH_CTRL__SHA512SUM0R;
        FUNCT7__SHA512SUM1R: zknh_control = ZKNH_CTRL__SHA512SUM1R;
        FUNCT7__SHA512SIG0L: zknh_control = ZKNH_CTRL__SHA512SIG0L;
        FUNCT7__SHA512SIG1L: zknh_control = ZKNH_CTRL__SHA512SIG1L;
        FUNCT7__SHA512SIG0H: zknh_control = ZKNH_CTRL__SHA512SIG0H;
        FUNCT7__SHA512SIG1H: zknh_control = ZKNH_CTRL__SHA512SIG1H;
        default:             zknh_control = ZKNH_CTRL__NONE;
      endcase
    else
      zknh_control = ZKNH_CTRL__NONE;

endmodule
