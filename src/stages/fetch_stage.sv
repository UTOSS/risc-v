`include "src/timescale.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module fetch_stage
  ( output if_to_id_t if_to_id
  , input ex_to_if_t  ex_to_if

  , input wire clk
  , input wire reset
  , input wire stall_f
  , input wire flush_f

  , output addr_t imem__address
  , input data_t imem__data
);
  // The use of distinct registers for prev, cur and next PC requires some explanation. Below is the
  // timing diagram of the instruction retireval and subsequenct passing of the relevant data to
  // decode stage. Importantly, notice the one clock-cycle lag between PC placed on the `imem
  // address` line and the instruction on the `imem data`, this is due to us using synchronous
  // memory for instructions (and data for that matter).
  //
  // When it comes to decode stage, it expects instruction to be passed along with the PC value that
  // corresponds to it. Therefore since the instruction "lags" by one cycle, hence the PC value has
  // to also lag by one cycle, and therefore we provide `pc_prev` to ID's `pc_cur`.
  //
  // fetch timeline:
  //                                     module snapshot
  //                                   +----------------+
  // imem address  : < prev PC       > | < cur PC     > | < next PC    > | < 2x next PC >
  // imem data     : < 2x prev instr > | < prev instr > | < cur instr  > | < next instr >
  // if->id.pc_cur : < 2x prev PC    > | < prev PC    > | < cur PC     > | < next PC    >
  //                                   |                |
  // decode timeline:                  |                |
  //                                   |                |
  // if->id.pc_cur :                   | < prev PC    > | < cur PC    > | < next PC    >
  // if->id.instr  :                   | < prev instr > | < cur instr > | < next instr >
  //                                   +----------------+

  addr_t pc_prev;
  addr_t pc_cur;
  addr_t pc_next;

  always_comb
    case (ex_to_if.pc_src)
      PC_SRC__INCREMENT:  pc_next = pc_cur + 32'h4;
      PC_SRC__ALU_RESULT: pc_next = ex_to_if.pc_target;
      default:            pc_next = 32'hx;
    endcase

  always_ff @ (posedge clk)
    if (!stall_f) pc_cur <= reset ? 0 : pc_next;

  always_ff @ (posedge clk)
    if (!stall_f) pc_prev <= reset ? 0 : pc_cur;

  // With synchronous instruction memory, one in-flight instruction can arrive after stall_f rises.
  // Keep a one-entry skid copy so decode can consume it once the stall is released;
  //
  // NOTE: this takes up extra space, we could have just used the existing space in the IF->ID
  // register, but that would require breaking the combinational protocol of the stage logic;
  // revisit if space becomes a problem
  instr_t stalled_instr;
  logic stalled_instr_valid;

  always_ff @ (posedge clk)
    if (reset)
      {stalled_instr, stalled_instr_valid} <= {instr_t'(0)  , 1'b0};
    else if (flush_f)
      {stalled_instr, stalled_instr_valid} <= {stalled_instr, 1'b0};
    else if (stall_f && !stalled_instr_valid)
      {stalled_instr, stalled_instr_valid} <= {imem__data   , 1'b1};
    else if (!stall_f && stalled_instr_valid)
      {stalled_instr, stalled_instr_valid} <= {stalled_instr, 1'b0};

  assign imem__address = pc_cur;

  assign if_to_id.instruction = stalled_instr_valid ? stalled_instr : imem__data;
  assign if_to_id.pc_cur      = pc_prev;
  assign if_to_id.pc_plus_4   = pc_prev + 32'h4; // TODO: revisit

  // TODO: probably can just get rid of those altogether
  wire unused = &{ex_to_if.pc_old, ex_to_if.imm_ext};
endmodule
