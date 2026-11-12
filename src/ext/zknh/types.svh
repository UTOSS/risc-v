`ifndef EXT__ZKNH__TYPES
`define EXT__ZKNH__TYPES

`include "src/timescale.svh"

/* verilator lint_off DECLFILENAME */
package ext__zknh__types;
/* verilator lint_on DECLFILENAME */
  // One selector per RV32 Zknh instruction; see the scalar cryptography
  // specification, section "Zknh - NIST Suite: Hash Function Instructions".
  typedef enum logic [3:0]
    { ZKNH_CTRL__NONE        = 4'b0000
    , ZKNH_CTRL__SHA256SUM0  = 4'b0001
    , ZKNH_CTRL__SHA256SUM1  = 4'b0010
    , ZKNH_CTRL__SHA256SIG0  = 4'b0011
    , ZKNH_CTRL__SHA256SIG1  = 4'b0100
    , ZKNH_CTRL__SHA512SUM0R = 4'b0101
    , ZKNH_CTRL__SHA512SUM1R = 4'b0110
    , ZKNH_CTRL__SHA512SIG0L = 4'b0111
    , ZKNH_CTRL__SHA512SIG1L = 4'b1000
    , ZKNH_CTRL__SHA512SIG0H = 4'b1001
    , ZKNH_CTRL__SHA512SIG1H = 4'b1010
    } zknh_control_t;

endpackage

`endif
