`include "src/timescale.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"

/* verilator lint_off UNUSEDSIGNAL */
module instruction_reader
  ( input  addr_t  pc_i
  , input  data_t  cur_word_i
  , input  data_t  next_word_i

  , output instr_t instr_raw_o
  , output addr_t  instr_pc_o
  , output addr_t  instr_next_pc_o
  , output logic   instr_is_compressed_o
  , output logic   instr_is_split_o
  );
/* verilator lint_on UNUSEDSIGNAL */

  logic [15:0] selected_halfword;
  logic        selected_is_32b;

  assign selected_halfword =
    pc_i[1] ? cur_word_i[31:16] : cur_word_i[15:0];

  assign selected_is_32b =
    selected_halfword[1:0] == 2'b11;

  assign instr_pc_o =
    pc_i;

  assign instr_is_compressed_o =
    !selected_is_32b;

  assign instr_is_split_o =
    selected_is_32b && pc_i[1];

  assign instr_next_pc_o =
    pc_i + (instr_is_compressed_o ? 32'd2 : 32'd4);

  assign instr_raw_o =
    instr_is_compressed_o ? {16'b0, selected_halfword} :
    instr_is_split_o      ? {next_word_i[15:0], cur_word_i[31:16]} :
                            cur_word_i;

endmodule
