/* module for fetching instructions
 *
 * concerns itself with reading instruction from the instruction memory, as well as managing the
 * program counter (PC); implemented as a Moore FSM
 */

`include "src/utils.svh"
`include "src/types.svh"

module fetch ( input  wire     clk
             , input  wire     reset
             , input  wire     cfsm__pc_update
             , input  pc_src_t cfsm__pc_src
             , input  imm_t    imm_ext
             , output instr_t  instr
             );

  addr_t pc_cur, pc_next;

  always @ (*) begin
    if (cfsm__pc_update) begin
      case (cfsm__pc_src)
        PC_SRC__INCREMENT: pc_next <= pc_cur + 32'h4;
        PC_SRC__JUMP:      pc_next <= pc_cur + imm_ext;
      endcase
    end else begin
      pc_next <= pc_cur;
    end
  end

  always @ (posedge clk) begin
    if (reset) pc_cur <= 32'h00000000;
    else       pc_cur <= pc_next;
  end

  MA instruction_memory
    ( .A   ( pc_cur       )
    , .WD  ( 32'hxxxxxxxx )
    , .WE  ( `FALSE       )
    , .CLK ( clk          )
    , .RD  ( instr        )
    );

endmodule
