`ifndef EXT__A__TYPES
`define EXT__A__TYPES

/* verilator lint_off DECLFILENAME */
package ext__a__types;
/* verilator lint_on DECLFILENAME */

  // the operation an atomic instruction asks the memory stage to perform; `A_OP__NONE` means the
  // instruction in flight is not an atomic one and the memory stage should behave as it always has
  //
  // only the `.w` (word) variants are listed: `.d` is RV64A-only and we are a 32-bit core
  typedef enum logic [3:0]
    { A_OP__NONE    = 4'b0000
    , A_OP__LR      = 4'b0001 // load-reserved
    , A_OP__SC      = 4'b0010 // store-conditional
    , A_OP__AMOSWAP = 4'b0011
    , A_OP__AMOADD  = 4'b0100
    , A_OP__AMOXOR  = 4'b0101
    , A_OP__AMOAND  = 4'b0110
    , A_OP__AMOOR   = 4'b0111
    , A_OP__AMOMIN  = 4'b1000 // signed
    , A_OP__AMOMAX  = 4'b1001 // signed
    , A_OP__AMOMINU = 4'b1010 // unsigned
    , A_OP__AMOMAXU = 4'b1011 // unsigned
    } a_op_t;

endpackage

`endif
