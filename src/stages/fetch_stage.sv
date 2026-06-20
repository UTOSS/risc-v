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
//use these to test
  , output addr_t imem__address //output to instruction memory
  , input data_t imem__data //get input instruction/data from instruction memory at the address specified by imem__address
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
 // RVC/C-extension fetch helpers.
  always_comb
    case (ex_to_if.pc_src)
    //  PC_SRC__INCREMENT:  pc_next = pc_cur + 32'h4;
      PC_SRC__INCREMENT:  pc_next = {pc_cur[31:2], 2'b00} + 32'd4;
      PC_SRC__ALU_RESULT: pc_next = ex_to_if.pc_target;
      default:            pc_next = 32'hx;
    endcase
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
  //assign imem__address = pc_cur;
assign imem__address = {pc_cur[31:2], 2'b00};
instr_t final_instr;
logic   final_illegal;
instr_t decompressed_instr;
logic compressed_illegal;
logic reader_inst_is_compressed;
logic reader_inst_is_split;
instr_t reader_instr_raw;
addr_t reader_instr_pc;
addr_t reader_next_pc;
//state bit to indicate : currently waiting to finish a split instruction
logic  split_wait_valid;
data_t split_wait_cur_word;
addr_t split_wait_pc;
logic need_split_wait;
logic buffer_after_split;
logic hold_pc_for_split_buffer;
//a safety instruction that doesnt do anything
//outputted when we need to wait an extra cycle to fetch a split 32-bit instruction
localparam instr_t NOP = 32'h00000013;
//for buffer for when two compressed instructions are back to back,
// and the second one is in the same 32-bit word as the first one,
//so we can just buffer the whole word and then read the second instruction
//from it without needing to fetch again from memory.
//This is an optimization to avoid unnecessary memory accesses for
//consecutive compressed instructions that happen to be in the same word.
logic  buffered_word_valid;
data_t buffered_word;
addr_t buffered_pc;
// buffered_pc tells the reader which halfword inside buffered_word to use.
logic  use_buffer;
logic  buffer_next_same_word;
addr_t reader_pc_i;
data_t reader_cur_word_i;
data_t reader_next_word;
wire unused = &{
  ex_to_if.pc_old
, ex_to_if.imm_ext
, final_illegal
};
instruction_reader u_reader
  ( .pc_i                  (reader_pc_i)
  , .cur_word_i            (reader_cur_word_i)
  , .next_word_i           (reader_next_word)
  , .instr_raw_o           (reader_instr_raw)
  , .instr_pc_o            (reader_instr_pc)
  , .instr_next_pc_o       (reader_next_pc)
  , .instr_is_compressed_o (reader_inst_is_compressed)
  , .instr_is_split_o      (reader_inst_is_split)
  );
// TODO: Replace with real compressed decoder once C decompressor module is merged.
// For now, compressed instructions are converted to NOP so fetch-stage integration builds.
assign decompressed_instr = NOP;
assign compressed_illegal = 1'b0;
always_ff @ (posedge clk)
  if (reset)
    pc_cur <= addr_t'(0);
  else if (!stall_f && !hold_pc_for_split_buffer)
    pc_cur <= pc_next;
always_ff @ (posedge clk)
  if (reset)
    pc_prev <= addr_t'(0);
  else if (!stall_f && !hold_pc_for_split_buffer)
    pc_prev <= pc_cur;
always_ff @ (posedge clk)
  if (reset || flush_f)
    {split_wait_valid, split_wait_cur_word, split_wait_pc}
      <= {1'b0, data_t'(0), addr_t'(0)};
  else if (!stall_f)
    if (split_wait_valid)
      split_wait_valid <= 1'b0;
    else if (need_split_wait)
      {split_wait_valid, split_wait_cur_word, split_wait_pc}
        <= {1'b1, reader_cur_word_i, reader_instr_pc};
always_ff @ (posedge clk)
  if (reset || flush_f)
    {buffered_word_valid, buffered_word, buffered_pc}
      <= {1'b0, data_t'(0), addr_t'(0)};
  else if (!stall_f)
    if (buffer_after_split)
      {buffered_word_valid, buffered_word, buffered_pc}
        <= {1'b1, imem__data, reader_next_pc};
    else if (use_buffer)
      buffered_word_valid <= 1'b0;
    else if (buffer_next_same_word)
      {buffered_word_valid, buffered_word, buffered_pc}
        <= {1'b1, reader_cur_word_i, reader_next_pc};
/*
    // If the next instruction we need to fetch is in the same word
    //as the current instruction, buffer it for the next cycle.
    //this case happens when we have a compressed instruction followed by another
    //instruction (compressed or the start of a split 32-bit instruction) that starts in
    //the same 32-bit word
*/
assign use_buffer = buffered_word_valid;
assign reader_pc_i =
  split_wait_valid ? split_wait_pc :
  use_buffer       ? buffered_pc :
                     pc_prev;
assign reader_cur_word_i =
  split_wait_valid   ? split_wait_cur_word :
  use_buffer         ? buffered_word :
  stalled_instr_valid ? data_t'(stalled_instr) :
                        imem__data;
assign reader_next_word =
  (split_wait_valid || use_buffer) ? imem__data : data_t'(0);
assign buffer_next_same_word =
  reader_inst_is_compressed &&
  (reader_next_pc[31:2] == reader_instr_pc[31:2]);
//Only insert the wait bubble the FIRST time you discover the split.
//Do not insert another bubble when you are already completing it.
assign need_split_wait =
  reader_inst_is_split && !split_wait_valid;
//I just completed a split instruction, and the next instruction starts inside
//the next word that just arrived. Save that word for the next cycle.
assign buffer_after_split =
  split_wait_valid &&
  reader_inst_is_split &&
  (reader_next_pc[31:2] == (reader_instr_pc[31:2] + 30'd1));
//prevents the memory fetch PC from advancing too far while you
//consume the buffered instruction
assign hold_pc_for_split_buffer =
  buffer_after_split;
assign final_instr =
  reader_inst_is_compressed ? decompressed_instr : reader_instr_raw;
assign final_illegal =
  reader_inst_is_compressed && compressed_illegal;
//final output to decode stage
assign if_to_id.instruction =
  need_split_wait ? NOP : final_instr;
assign if_to_id.pc_cur      = reader_instr_pc;
assign if_to_id.pc_plus_4   = reader_next_pc;
endmodule
