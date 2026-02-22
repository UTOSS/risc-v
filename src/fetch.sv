// module for fetching instructions
//
// concerns itself with reading instruction from the instruction memory, as well as managing the
// program counter (PC); implemented as a Moore FSM
//

`include "src/utils.svh"
`include "src/types.svh"

module fetch
  ( input  wire     clk
  , input  wire     reset
  , input  wire     cfsm__pc_update
  , input  pc_src_t cfsm__pc_src
  , input  wire     cfsm__ir_write

  /* verilator lint_off UNUSEDSIGNAL */
  , input addr_t alu_result_for_pc
  /* verilator lint_on UNUSEDSIGNAL */

  , input  imm_t    imm_ext
  , output addr_t   pc_cur
  , output addr_t   pc_old
  );

  addr_t pc_next;

  /* verilator lint_off LATCH */
  /* verilator lint_off COMBDLY */
  always @ (*) begin
    if (cfsm__pc_update) begin
      case (cfsm__pc_src)
        PC_SRC__INCREMENT: pc_next <= pc_cur + 32'h4;
        PC_SRC__JUMP:       pc_next <= pc_old + imm_ext;
        PC_SRC__ALU_RESULT: pc_next <= {alu_result_for_pc[31:1], 1'b0};
        default: ;
      endcase
    end else begin
      pc_next <= pc_cur;
    end
  end

  always @ (posedge clk) begin
    if (reset) pc_cur <= 32'h00000000;
    else pc_cur <= pc_next;

    if (cfsm__ir_write) begin
      pc_old <= pc_cur;
    end
  end

endmodule
