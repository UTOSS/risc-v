/* module for fetching instructions
 *
 * concerns itself with reading instruction from the instruction memory, as well as managing the
 * program counter (PC); implemented as a Moore FSM
 */

`include "src/utils.svh"
`include "src/types.svh"

module fetch ( input  wire     clk
             , input  wire     reset
             , input  wire     cfsm__pc_write
             , input  wire     cfsm__ir_write
             , input  addr_t   result
             , output addr_t   pc_cur
             , output addr_t   pc_old
             );

  always @ (posedge clk) begin
    if (reset)          pc_cur <= 32'h00000000;
    if (cfsm__pc_write) pc_cur <= result;
    if (cfsm__ir_write) pc_old <= pc_cur;
  end

endmodule
