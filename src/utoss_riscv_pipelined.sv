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

  // common declarations begin

  if_to_id_if  if_to_id_if();
  id_to_ex_if  id_to_ex_if();
  mem_to_wb_if mem_to_wb_if();

  data_t      wb_result;
  logic [4:0] wb_rd;

  // common declarations end

  // fetch stage start (@thatlittlegit)

  // fetch stage end

  // decode stage begin (@marwannismail)
  // TODO: move zero flag to Fetch stage
  // TODO: remove ALU result from control FSM (should not be added to Fetch stage according to the draw.io diagram note)
  Decode decode
    ( .IF_to_ID    (  if_to_id_if  )
    , .clk         (  clk          )
    , .reset       (  reset        )
    , .data        (  wb_result    )
    , .rd_wb       (  wb_rd        )
    , .zero_flag   (  zero_flag    )
    , .alu_result  (  alu_result   )
    , .ID_to_EX    (  id_to_ex_if  )
    );

  // decode stage end

  // execute stage begin (@MSh-786 and tandr3w)

  // execute stage end

  // memory stage begin (@Invisipac)

  // memory stage end

  // writeback stage begin (@TheDeepestSpace)

  write_back wb
    ( .clk         ( clk   )
    , .reset       ( reset )

    , .from_memory ( mem_to_wb_if.to_write_back )
    , .result      ( wb_result                  )
    , .rd          ( wb_rd                      )
    );

  // writeback stage end

  // hazard module begin (@DanielTaoHuang123)

  // hazard module end

endmodule
