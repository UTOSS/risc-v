`include "src/timescale.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module fetch_compressed
  ( output if_to_id_t if_to_id
  , input ex_to_if_t  ex_to_if
  , input wire clk
  , input wire reset
  , input wire stall_f
  , input wire flush_f
  , output addr_t imem__address
  , input data_t imem__data
  );

  addr_t pc_prev;
  addr_t pc_cur;
  addr_t pc_next;

  instr_t stalled_instr;
  logic stalled_instr_valid;

  instr_t final_instr;
  logic final_illegal;
  instr_t decompressed_instr;
  logic compressed_illegal;

  logic reader_inst_is_compressed;
  logic reader_inst_is_split;
  instr_t reader_instr_raw;
  addr_t reader_next_pc;

  logic split_wait_valid;
  data_t split_wait_cur_word;
  addr_t split_wait_pc;
  data_t split_wait_next_word;
  logic split_wait_next_word_valid;

  logic need_split_wait;
  logic buffer_after_split;
  logic hold_pc_for_split_buffer;

  localparam instr_t NOP = 32'h00000013;

  logic buffered_word_valid;
  data_t buffered_word;
  addr_t buffered_pc;

  logic use_buffer;
  logic buffer_next_same_word;

  addr_t reader_pc_i;
  data_t reader_cur_word_i;
  data_t reader_next_word;

  wire unused = &{
    ex_to_if.pc_old
  , ex_to_if.imm_ext
  , final_illegal
  };

  always_comb
    case (ex_to_if.pc_src)
      PC_SRC__INCREMENT:  pc_next = {pc_cur[31:2], 2'b00} + 32'd4;
      PC_SRC__ALU_RESULT: pc_next = ex_to_if.pc_target;
      default:            pc_next = 32'hx;
    endcase

  always_ff @ (posedge clk)
    if (reset)
      {stalled_instr, stalled_instr_valid} <= {instr_t'(0), 1'b0};
    else if (flush_f)
      {stalled_instr, stalled_instr_valid} <= {stalled_instr, 1'b0};
    else if (stall_f && !stalled_instr_valid)
      {stalled_instr, stalled_instr_valid} <= {instr_t'(imem__data), 1'b1};
    else if (!stall_f && stalled_instr_valid)
      {stalled_instr, stalled_instr_valid} <= {stalled_instr, 1'b0};

  assign imem__address = {pc_cur[31:2], 2'b00};

  instruction_reader u_reader
    ( .pc_i                  (reader_pc_i)
    , .cur_word_i            (reader_cur_word_i)
    , .next_word_i           (reader_next_word)
    , .instr_raw_o           (reader_instr_raw)
    , .instr_next_pc_o       (reader_next_pc)
    , .instr_is_compressed_o (reader_inst_is_compressed)
    , .instr_is_split_o      (reader_inst_is_split)
    );

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
      { split_wait_valid
      , split_wait_cur_word
      , split_wait_pc
      , split_wait_next_word
      , split_wait_next_word_valid
      } <= {1'b0, data_t'(0), addr_t'(0), data_t'(0), 1'b0};

    else if (!stall_f && split_wait_valid)
      { split_wait_valid
      , split_wait_next_word
      , split_wait_next_word_valid
      } <= {1'b0, data_t'(0), 1'b0};

    else if (!stall_f && need_split_wait)
      { split_wait_valid
      , split_wait_cur_word
      , split_wait_pc
      , split_wait_next_word
      , split_wait_next_word_valid
      } <= {1'b1, reader_cur_word_i, reader_pc_i, data_t'(0), 1'b0};

    else if (stall_f && split_wait_valid && !split_wait_next_word_valid)
      {split_wait_next_word, split_wait_next_word_valid} <= {imem__data, 1'b1};

  always_ff @ (posedge clk)
    if (reset || flush_f)
      {buffered_word_valid, buffered_word, buffered_pc}
        <= {1'b0, data_t'(0), addr_t'(0)};

    else if (!stall_f && buffer_after_split)
      {buffered_word_valid, buffered_word, buffered_pc}
        <= {1'b1, reader_next_word, reader_next_pc};

    else if (!stall_f && use_buffer)
      buffered_word_valid <= 1'b0;

    else if (!stall_f && buffer_next_same_word)
      {buffered_word_valid, buffered_word, buffered_pc}
        <= {1'b1, reader_cur_word_i, reader_next_pc};

  assign use_buffer = buffered_word_valid;

  assign reader_pc_i =
    split_wait_valid ? split_wait_pc :
    use_buffer       ? buffered_pc :
    pc_prev;

  assign reader_cur_word_i =
    split_wait_valid    ? split_wait_cur_word :
    use_buffer          ? buffered_word :
    stalled_instr_valid ? data_t'(stalled_instr) :
                          imem__data;

  assign reader_next_word =
    split_wait_valid ?
      (split_wait_next_word_valid ? split_wait_next_word : imem__data) :
    use_buffer ?
      imem__data :
      data_t'(0);

  assign buffer_next_same_word =
    reader_inst_is_compressed &&
    (reader_next_pc[31:2] == reader_pc_i[31:2]);

  assign need_split_wait =
    reader_inst_is_split && !split_wait_valid;

  assign buffer_after_split =
    split_wait_valid &&
    reader_inst_is_split &&
    (reader_next_pc[31:2] == (reader_pc_i[31:2] + 30'd1));

  assign hold_pc_for_split_buffer =
    buffer_after_split;

  assign final_instr =
    reader_inst_is_compressed ? decompressed_instr : reader_instr_raw;

  assign final_illegal =
    reader_inst_is_compressed && compressed_illegal;

  assign if_to_id.instruction =
    need_split_wait ? NOP : final_instr;

  assign if_to_id.pc_cur =
    reader_pc_i;

  assign if_to_id.pc_plus_4 =
    reader_next_pc;

endmodule
