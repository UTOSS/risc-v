`ifndef PKG_HAZARD_UNIT_VH
`define PKG_HAZARD_UNIT_VH

package pkg_hazard_unit;

  typedef enum logic [1:0]
    { FORWARD_A__EXECUTE_RD1       = 2'b00
    , FORWARD_A__WRITE_BACK_RESULT = 2'b01
    , FORWARD_A__MEMORY_ALU_RESULT = 2'b10
    } forward_a_t;

  typedef enum logic [1:0]
    { FORWARD_B__EXECUTE_RD2       = 2'b00
    , FORWARD_B__WRITE_BACK_RESULT = 2'b01
    , FORWARD_B__MEMORY_ALU_RESULT = 2'b10
    } forward_b_t;

endpackage

`endif
