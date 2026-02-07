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

  if_to_id_if  if_to_id_out_if();
  if_to_id_if  if_to_id_reg_if();

  id_to_ex_t   id_to_ex_out;
  id_to_ex_t   id_to_ex_reg;

  mem_to_wb_if mem_to_wb_if();

  data_t      wb_result;
  logic [4:0] wb_rd;

  // common declarations end

  // fetch stage start (@thatlittlegit)

  // fetch stage end

  // decode stage begin (@marwannismail)

  // TODO: this will blow up on us for large interfaces; i think we might need to use packed structs
  // to make cross-stage register assignments more elegant
  always_ff @ (posedge clk)
    if (reset) if_to_id_reg_if.instruction <= '0;
    else       if_to_id_reg_if.instruction <= if_to_id_out_if.instruction;

  // TODO: move zero flag to Fetch stage
  // TODO: remove ALU result from control FSM (should not be added to Fetch stage according to the draw.io diagram note)
  Decode decode
    ( .IF_to_ID    ( if_to_id_reg_if )
    , .clk         ( clk             )
    , .reset       ( reset           )
    , .data        ( wb_result       )
    , .rd_wb       ( wb_rd           )
    , .zero_flag   ( zero_flag       )
    , .alu_result  ( alu_result      )
    , .ID_to_EX    ( id_to_ex_out    )
    );

  // decode stage end

  // execute stage begin (@MSh-786 and tandr3w)

  always_ff @ (posedge clk)
    if (reset) id_to_ex_reg <= '0;
    else       id_to_ex_reg <= id_to_ex_out;

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
