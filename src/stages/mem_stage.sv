`include "src/headers/types.svh"

module Mem_Stage
( ex_to_mem_if.Memory EX_to_MEM
  // ( input logic [3:0] MemWriteM //interface
  // , input wire inRegWriteM //interface
  // , input reg [1:0] inResultSrcM //interface
  // , input reg [4:0] inRdM //interface
  // , input logic [2:0] funct3//interface
  // , input addr_t ALUResultM //interface
  , input data_t WriteDataM
  , input instr_t inPCPlus4M //straight from execute module
  , input data_t dataFromMemory
  , output wire outRegWriteM
  // , output reg [1:0] outResultSrcM
  , output data_t dataToMemory
  // , output instr_t outPCPlus4M
  , output logic [3:0] MemWriteByteAddress
  , mem_to_wb_if.to_write_back MEM_to_WB
  // , output data_t ReadDataM //interface
  // , output reg [4:0] outRdM//interface
  );

  MemoryLoader memory_loader
    ( .memory_data (dataFromMemory)
    , .memory_address (ALUResultM)
    , .funct3 (funct3)
    , .dataB ( WriteDataM )
    , .mem_load_result ( MEM_to_WB.read_data )
    , .MemWriteByteAddress ( MemWriteByteAddress )
    , .__tmp_MemData (dataToMemory)
    );
//maybe need regwrite in mem_to_wb interface
  always @(posedge clk)
  if (reset) begin
  MEM_to_WB.RegWriteW <= 'b0; //
  MEM_to_WB.cfsm__result_src <= 'b0;
  MEM_to_WB.rd <= 'b0;
  MEM_to_WB.alu_result <= 'b0;
  end
  else begin
  MEM_to_WB.RegWriteW <= EX_to_MEM.RegWrite; //
  MEM_to_WB.cfsm__result_src <= EX_to_MEM.ResultSrc;
  MEM_to_WB.rd <= EX_to_MEM.rd;
  MEM_to_WB.alu_result <= EX_to_MEM.alu_result;
  end
  // assign outPCPlus4M = inPCPlus4M;

endmodule