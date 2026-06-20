`include "src/timescale.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"
//instantiate inside fetch stage

// Purpose:

// This module should  sit between fetch_stage and instruction memory.
// It should output one complete instruction at a time to the decode stage.
//
// This module reads one complete instruction from synchronous instruction memory.
//
// Cases handled:
//   1. 16-bit compressed instruction starting in lower or upper halfword.
//   2. 32-bit instruction starting at lower halfword, fully inside current word.
//   3. 32-bit instruction starting at upper halfword, split across two words.
//
// Notes:
//   - instr_o is always 32 bits for pipeline compatibility.
//   - If compressed, instr_o = {16'b0, raw_16_bit_instruction} for now.
//   - Decompression happens later in a separate module.



module instruction_reader
  ( input addr_t pc_i //current fetch PC from fetch_stage
  , input  data_t  cur_word_i //current 32-bit word read from instruction memory at the aligned PC address
  , input  data_t  next_word_i //next 32-bit word read from instruction memory at the next aligned PC address
  , output instr_t instr_raw_o
  , output addr_t  instr_pc_o
  , output addr_t  instr_next_pc_o
   , output logic   instr_is_compressed_o
  , output logic   instr_is_split_o
  );
   logic [15:0] selected_halfword;
  logic        selected_is_32b;

assign selected_halfword= pc_i[1] ? cur_word_i[31:16] : cur_word_i[15:0];
assign selected_is_32b = selected_halfword[1:0] == 2'b11;

always_comb begin

 instr_raw_o           = instr_t'(0);
    instr_pc_o            = pc_i;
    instr_next_pc_o       = pc_i;
    instr_is_compressed_o = 1'b0;
    instr_is_split_o      = 1'b0;

// 1. 16-bit compressed instruction starting in lower or upper halfword.
if(selected_is_32b==1'b0) begin
instr_raw_o = {16'b0, selected_halfword}; // output the 16-bit instruction in the lower half of instr_raw_o, upper half is zero-padded
instr_pc_o = pc_i;
instr_next_pc_o = pc_i + 32'd2; // next PC is current PC + 2
instr_is_compressed_o = 1'b1;
instr_is_split_o = 1'b0;
end

//   2. 32-bit instruction starting at lower halfword, fully inside current word.
else if(pc_i[1] == 1'b0) begin
instr_raw_o = cur_word_i; // the whole 32-bit instruction is in the current word
instr_pc_o = pc_i;
instr_next_pc_o = pc_i + 32'd4; // next PC is current PC + 4
instr_is_compressed_o = 1'b0;
instr_is_split_o = 1'b0;
end


//   3. 32-bit instruction starting at upper halfword, split across two words.
else begin
instr_raw_o = {next_word_i[15:0], cur_word_i[31:16]}; // combine the upper half of the current word and the lower half of the next word
instr_pc_o = pc_i;
instr_next_pc_o = pc_i + 32'd4; // next PC is current PC + 4
instr_is_compressed_o = 1'b0;
instr_is_split_o = 1'b1; // this instruction is split across two words
end

end


wire unused = &{
  next_word_i[31:16]
};


endmodule




