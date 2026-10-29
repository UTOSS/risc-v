`ifndef EXT__M__TYPES
`define EXT__M__TYPES

/* verilator lint_off DECLFILENAME */
package ext__m__types;
/* verilator lint_on DECLFILENAME */
  typedef enum logic [1:0]
    {
      M_ALU_CTRL__MUL    = 2'b00
    , M_ALU_CTRL__MULH   = 2'b01
    , M_ALU_CTRL__MULHSU = 2'b10
    , M_ALU_CTRL__MULHU  = 2'b11
    } m_mul_control_t;

  typedef enum logic [1:0]
    {
      M_ALU_CTRL__DIV  = 2'b00
    , M_ALU_CTRL__DIVU = 2'b01
    , M_ALU_CTRL__REM  = 2'b10
    , M_ALU_CTRL__REMU = 2'b11
    } m_div_control_t;

endpackage

`endif
