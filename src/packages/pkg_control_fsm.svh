`ifndef PKG_CONTROL_FSM_VH
`define PKG_CONTROL_FSM_VH

/* verilator lint_off TIMESCALEMOD */
package pkg_control_fsm;
/* verilator lint_on TIMESCALEMOD */

    // parameterize states (binary encoding)
    typedef enum logic[4:0]
      { FETCH      = 5'b00000
      , DECODE     = 5'b00001
      , EXECUTER   = 5'b00010
      , UNCONDJUMP = 5'b00011
      , EXECUTEI   = 5'b00100
      , MEMADR     = 5'b00101
      , ALUWB      = 5'b00110
      , MEMWRITE   = 5'b00111
      , MEMREAD    = 5'b01000
      , MEMWB      = 5'b01001
      , BRANCHIFEQ = 5'b01010
      //new states for lui and auipc
      , LUI        = 5'b01011
      , AUIPC      = 5'b01100
      , JALR_CALC  = 5'b01101 // calculate rs1 + imm, store in alu_out
      , JALR_STEP2 = 5'b01110 // link and use alu_out to update PC
      // new state for remaining branch instructions
      , BRANCHCOMP = 5'b01111
      , FETCH_WAIT = 5'b10000
      } state_t;

endpackage: pkg_control_fsm

`endif
