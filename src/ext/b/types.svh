`ifndef EXT__B__TYPES
`define EXT__B__TYPES

/* verilator lint_off DECLFILENAME */
package ext__b__types;
/* verilator lint_on DECLFILENAME */
  typedef enum logic [4:0]
    { B_ALU_CTRL__NONE   = 5'b00000
    , B_ALU_CTRL__SH1ADD = 5'b00001
    , B_ALU_CTRL__SH2ADD = 5'b00010
    , B_ALU_CTRL__SH3ADD = 5'b00011
    , B_ALU_CTRL__ANDN   = 5'b00100
    , B_ALU_CTRL__ORN    = 5'b00101
    , B_ALU_CTRL__XNOR   = 5'b00110
    , B_ALU_CTRL__MIN    = 5'b00111
    , B_ALU_CTRL__MAX    = 5'b01000
    , B_ALU_CTRL__MINU   = 5'b01001
    , B_ALU_CTRL__MAXU   = 5'b01010
    , B_ALU_CTRL__SEXTB  = 5'b01011
    , B_ALU_CTRL__SEXTH  = 5'b01100
    , B_ALU_CTRL__ZEXTH  = 5'b01101
    , B_ALU_CTRL__CLZ    = 5'b01110
    , B_ALU_CTRL__CTZ    = 5'b01111
    , B_ALU_CTRL__CPOP   = 5'b10000
    , B_ALU_CTRL__ROL    = 5'b10001
    , B_ALU_CTRL__ROR    = 5'b10010
    , B_ALU_CTRL__RORI   = 5'b10011
    , B_ALU_CTRL__ORCB   = 5'b10100
    , B_ALU_CTRL__REV8   = 5'b10101
    } b_alu_control_t;

endpackage

`endif
