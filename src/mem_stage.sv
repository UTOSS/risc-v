`include "src/types.svh"

module Mem_Stage (
    input wire inRegWriteM,
    input reg [1:0] inResultSrcM,
    input reg [4:0] inRdM, 
    input instr_t inPCPlus4M,
    input data_t dataFromMemory,
    input logic [2:0] funct3,
    input addr_t ALUResultM,
    input data_t WriteDataM,
    output data_t ReadDataM,
    output wire outRegWriteM,
    output reg [1:0] outResultSrcM,
    output data_t dataToMemory,
    output instr_t outPCPlus4M,
    output reg [4:0] outRdM,
    output logic [3:0] MemWriteByteAddress
);

MemoryLoader memory_loader (
    .memory_data (dataFromMemory),
    .memory_address (ALUResultM),
    .funct3 (funct3),
    .dataB ( WriteDataM ),
    .mem_load_result ( ReadDataM ),
    .MemWriteByteAddress ( MemWriteByteAddress ),
    .__tmp_MemData (dataToMemory)
);

assign outRegWriteM = inRegWriteM;
assign outResultSrcM = inResultSrcM;
assign outRdM = inRdM;
assign outPCPlus4M = inPCPlus4M;

endmodule