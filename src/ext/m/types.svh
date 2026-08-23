`ifndef EXT__M__TYPES
`define EXT__M__TYPES

/* verilator lint_off DECLFILENAME */
package ext__m__types;
/* verilator lint_on DECLFILENAME */
  typedef enum logic [2:0]
    {
      M_ALU_CTRL__MUL_NONE = 3'b000
    , M_ALU_CTRL__MUL      = 3'b001
    , M_ALU_CTRL__MULH     = 3'b010
    , M_ALU_CTRL__MULHSU   = 3'b011
    , M_ALU_CTRL__MULHU    = 3'b100
    } m_mul_control_t;

  typedef enum logic [2:0]
    {
      M_ALU_CTRL__DIV_NONE = 3'b000
    , M_ALU_CTRL__DIV      = 3'b001
    , M_ALU_CTRL__DIVU     = 3'b010
    , M_ALU_CTRL__REM      = 3'b011
    , M_ALU_CTRL__REMU     = 3'b100
    } m_div_control_t;

endpackage

`endif
