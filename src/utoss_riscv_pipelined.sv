`include "src/headers/types.svh"

// pipelined implementation of our core
module utoss_riscv_pipelined
  ( input wire clk
  , input wire reset

  // instruction memory interface begin
  , output addr_t       memory_instr__address
  , output data_t       memory_instr__write_data
  , output logic  [3:0] memory_instr__write_enable
  , input  data_t       memory_instr__read_data
  // instruction memory interface end

  // data memory interface begin
  , output addr_t       memory_data__address
  , output data_t       memory_data__write_data
  , output logic  [3:0] memory_data__write_enable
  , input  data_t       memory_data__read_data
  // data memory interface end
  );

  // common declarations

  // fetch stage start (@thatlittlegit)

  // fetch stage end

  // decode stage begin (@marwannismail)

  // decode stage end

  // execute stage begin (@MSh-786 and tandr3w)

  // execute stage end

  // memory stage begin (@Invisipac)

  // memory stage end

  // writeback stage begin (@TheDeepestSpace)

  // writeback stage end

  // hazard module begin (@DanielTaoHuang123)

  // hazard module end

endmodule
