`include "src/headers/types.svh"

module Mem_Stage
  ( input logic [3:0] MemWriteM //interface
  , input wire inRegWriteM //interface
  , input reg [1:0] inResultSrcM //interface
  , input reg [4:0] inRdM //interface
  // , input instr_t inPCPlus4M //interface
  , input data_t dataFromMemory
  , input logic [2:0] funct3//interface
  , input addr_t ALUResultM //interface
  , input data_t WriteDataM //interface
  , output data_t ReadDataM
  , output wire outRegWriteM
  , output reg [1:0] outResultSrcM
  , output data_t dataToMemory
  // , output instr_t outPCPlus4M
  , output reg [4:0] outRdM
  , output logic [3:0] MemWriteByteAddress
  );

  MemoryLoader memory_loader
    ( .memory_data (dataFromMemory)
    , .memory_address (ALUResultM)
    , .funct3 (funct3)
    , .dataB ( WriteDataM )
    , .mem_load_result ( ReadDataM )
    , .MemWriteByteAddress ( MemWriteByteAddress )
    , .__tmp_MemData (dataToMemory)
    );

  assign outRegWriteM = inRegWriteM;
  assign outResultSrcM = inResultSrcM;
  assign outRdM = inRdM;
  // assign outPCPlus4M = inPCPlus4M;

endmodule