`ifndef EXT__B__TYPES
`define EXT__B__TYPES

package ext__b__types;

  typedef enum logic [3:0]
    { B_ALU_CTRL__NONE   = 4'b0000
    , B_ALU_CTRL__SH1ADD = 4'b0001
    , B_ALU_CTRL__SH2ADD = 4'b0010
    , B_ALU_CTRL__SH3ADD = 4'b0011
    , B_ALU_CTRL__ANDN   = 4'b0100
    , B_ALU_CTRL__ORN    = 4'b0101
    , B_ALU_CTRL__XNOR   = 4'b0110
    } b_alu_control_t;

endpackage;

`endif
