`include "src/headers/params.svh"
`include "src/headers/types.svh"

interface ex_to_if_if (input clk);
  pc_src_t pc_src;
  addr_t pc_old;
  imm_t imm_ext;
  addr_t alu_result_for_pc;

  modport Execute
  ( input clk
  , output pc_src
  , output pc_old
  , output imm_ext
  , output alu_result_for_pc
  );

  modport Fetch
  ( input clk
  , input pc_src
  , input pc_old
  , input imm_ext
  , input alu_result_for_pc
  );

endinterface
