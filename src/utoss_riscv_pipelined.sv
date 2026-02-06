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

  id_to_ex_if  id_to_ex_out_if();
  id_to_ex_if  id_to_ex_reg_if();

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
    , .ID_to_EX    ( id_to_ex_out_if )
    );

  // decode stage end

  // execute stage begin (@MSh-786 and tandr3w)

  // TODO: convert into packed structs to make this more elegant
  always_ff @ (posedge clk)
    if (reset)
      { id_to_ex_reg_if.ALUSrcA
      , id_to_ex_reg_if.ALUSrcB
      , id_to_ex_reg_if.ResultSrc
      , id_to_ex_reg_if.AdrSrc
      , id_to_ex_reg_if.pc_update
      , id_to_ex_reg_if.pc_src
      , id_to_ex_reg_if.IRWrite
      , id_to_ex_reg_if.Branch
      , id_to_ex_reg_if.MemWriteByteAddress
      , id_to_ex_reg_if.FSMState
      , id_to_ex_reg_if.MemWrite
      , id_to_ex_reg_if.RegWrite
      , id_to_ex_reg_if.ALUControl
      , id_to_ex_reg_if.funct3
      , id_to_ex_reg_if.funct7
      , id_to_ex_reg_if.rd1
      , id_to_ex_reg_if.rd2
      , id_to_ex_reg_if.rd
      , id_to_ex_reg_if.rs1
      , id_to_ex_reg_if.rs2
      , id_to_ex_reg_if.imm_ext
      } <= '0;
    else
      { id_to_ex_reg_if.ALUSrcA
      , id_to_ex_reg_if.ALUSrcB
      , id_to_ex_reg_if.ResultSrc
      , id_to_ex_reg_if.AdrSrc
      , id_to_ex_reg_if.pc_update
      , id_to_ex_reg_if.pc_src
      , id_to_ex_reg_if.IRWrite
      , id_to_ex_reg_if.Branch
      , id_to_ex_reg_if.MemWriteByteAddress
      , id_to_ex_reg_if.FSMState
      , id_to_ex_reg_if.MemWrite
      , id_to_ex_reg_if.RegWrite
      , id_to_ex_reg_if.ALUControl
      , id_to_ex_reg_if.funct3
      , id_to_ex_reg_if.funct7
      , id_to_ex_reg_if.rd1
      , id_to_ex_reg_if.rd2
      , id_to_ex_reg_if.rd
      , id_to_ex_reg_if.rs1
      , id_to_ex_reg_if.rs2
      , id_to_ex_reg_if.imm_ext
      }
      <=
      { id_to_ex_out_if.ALUSrcA
      , id_to_ex_out_if.ALUSrcB
      , id_to_ex_out_if.ResultSrc
      , id_to_ex_out_if.AdrSrc
      , id_to_ex_out_if.pc_update
      , id_to_ex_out_if.pc_src
      , id_to_ex_out_if.IRWrite
      , id_to_ex_out_if.Branch
      , id_to_ex_out_if.MemWriteByteAddress
      , id_to_ex_out_if.FSMState
      , id_to_ex_out_if.MemWrite
      , id_to_ex_out_if.RegWrite
      , id_to_ex_out_if.ALUControl
      , id_to_ex_out_if.funct3
      , id_to_ex_out_if.funct7
      , id_to_ex_out_if.rd1
      , id_to_ex_out_if.rd2
      , id_to_ex_out_if.rd
      , id_to_ex_out_if.rs1
      , id_to_ex_out_if.rs2
      , id_to_ex_out_if.imm_ext
      };

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
