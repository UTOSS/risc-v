`include "src/timescale.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/headers/utils.svh"
`include "src/ext/a/types.svh"

// Decoder for the A (atomic) extension.
//
// Atomic instructions reuse the R-type layout, but the field that every other instruction treats as
// a single 7-bit `funct7` is subdivided into {funct5, aq, rl}:
//
//   31    27  26   25   24   20 19   15 14  12 11    7 6      0
//  +--------+----+----+-------+-------+------+-------+---------+
//  | funct5 | aq | rl |  rs2  |  rs1  |funct3|  rd   | 0101111 |
//  +--------+----+----+-------+-------+------+-------+---------+
//           \______ what is `funct7` elsewhere ______/
//
// So the operation must be selected on `funct7[6:2]` rather than on `funct7` as a whole, otherwise
// the same instruction decodes differently depending on its ordering bits.
//
// `aq`/`rl` constrain how this hart's memory accesses may be reordered relative to other harts. We
// are a single-hart core with no cache, store buffer or MMU, so nothing can be reordered and the
// bits are decoded and carried down the pipeline but not acted upon; see the "Future plan" section
// of the A extension planning doc.
/* verilator lint_off DECLFILENAME */
module ext__a__decoder
/* verilator lint_on DECLFILENAME */
  ( input opcode_t   opcode
  , input wire [2:0] funct3
  , input wire [6:0] funct7
  , input reg_t      rs2

  , output ext__a__types::a_op_t a_op
  , output var logic             aq
  , output var logic             rl
  , output var logic             is_illegal
  );

  import ext__a__types::*;

  // RV32A only defines the word-wide variants; funct3 = 3'b011 (`.d`) is RV64A-only
  localparam bit [2:0] FUNCT3__W = 3'b010;

  localparam bit [4:0] FUNCT5__LR      = 5'b00010;
  localparam bit [4:0] FUNCT5__SC      = 5'b00011;
  localparam bit [4:0] FUNCT5__AMOSWAP = 5'b00001;
  localparam bit [4:0] FUNCT5__AMOADD  = 5'b00000;
  localparam bit [4:0] FUNCT5__AMOXOR  = 5'b00100;
  localparam bit [4:0] FUNCT5__AMOAND  = 5'b01100;
  localparam bit [4:0] FUNCT5__AMOOR   = 5'b01000;
  localparam bit [4:0] FUNCT5__AMOMIN  = 5'b10000;
  localparam bit [4:0] FUNCT5__AMOMAX  = 5'b10100;
  localparam bit [4:0] FUNCT5__AMOMINU = 5'b11000;
  localparam bit [4:0] FUNCT5__AMOMAXU = 5'b11100;

  wire is_atomic_opcode = opcode == OPCODE_AMO;
  wire [4:0] funct5     = funct7[6:2];

  // ordering bits are only meaningful for atomics; keep them clear for every other instruction so
  // that a regular R-type `funct7` never looks like an acquire/release request further down the
  // pipeline
  assign aq = is_atomic_opcode & funct7[1];
  assign rl = is_atomic_opcode & funct7[0];

  a_op_t decoded_op;
  always_comb
    case (funct5)
      FUNCT5__LR:      decoded_op = A_OP__LR;
      FUNCT5__SC:      decoded_op = A_OP__SC;
      FUNCT5__AMOSWAP: decoded_op = A_OP__AMOSWAP;
      FUNCT5__AMOADD:  decoded_op = A_OP__AMOADD;
      FUNCT5__AMOXOR:  decoded_op = A_OP__AMOXOR;
      FUNCT5__AMOAND:  decoded_op = A_OP__AMOAND;
      FUNCT5__AMOOR:   decoded_op = A_OP__AMOOR;
      FUNCT5__AMOMIN:  decoded_op = A_OP__AMOMIN;
      FUNCT5__AMOMAX:  decoded_op = A_OP__AMOMAX;
      FUNCT5__AMOMINU: decoded_op = A_OP__AMOMINU;
      FUNCT5__AMOMAXU: decoded_op = A_OP__AMOMAXU;
      default:         decoded_op = A_OP__NONE;
    endcase

  // `lr.w` reads no second operand; the spec reserves the encodings with rs2 != 0
  wire rs2_reserved     = (decoded_op == A_OP__LR) && (rs2 != 5'd0);
  wire width_supported  = funct3 == FUNCT3__W;
  wire encoding_defined = width_supported && !rs2_reserved && (decoded_op != A_OP__NONE);

  // an undefined encoding must not reach the memory stage as an atomic, otherwise it would perform
  // a read-modify-write we never asked for
  always_comb
    if (is_atomic_opcode && encoding_defined) a_op = decoded_op;
    else                                      a_op = A_OP__NONE;

  // NOTE: nothing consumes this yet -- we have no trap/exception support. It is produced so that
  // the encoding gaps are documented and testable, and so that illegal-instruction traps have
  // something to hang off once the privileged architecture lands.
  always_comb
    if (is_atomic_opcode) is_illegal = !encoding_defined;
    else                  is_illegal = `FALSE;

endmodule
