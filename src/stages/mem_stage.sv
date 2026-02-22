`include "src/headers/types.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/mem_to_wb_if.svh"

module Mem_Stage
( ex_to_mem_t EX_to_MEM
  , input wire [2:0] funct3
  , input data_t dataFromMemory
  , output data_t dataToMemory
  // , output logic [3:0] MemWriteByteAddress
  , mem_to_wb_t MEM_to_WB
  );

  // Inputs from EX_to_MEM interface
  data_t WriteDataM;
  data_t ALUResultM;
  logic [4:0] RdM;
  logic MemWrite;

  logic [3:0] MemWriteByteAddress;

  assign WriteDataM = EX_to_MEM.WriteDataE;
  assign ALUResultM = EX_to_MEM.alu_result;
  assign RdM = EX_to_MEM.rd;
  assign MemWrite = EX_to_MEM.MemWrite;

  logic [3:0] tempMemWriteByteAddress;
  MemoryLoader memory_loader
    ( .memory_data         ( dataFromMemory          )
    , .memory_address      ( ALUResultM              )
    , .funct3              ( funct3                  )
    , .dataB               ( WriteDataM              )
    , .mem_load_result     ( MEM_to_WB.read_data     )
    , .MemWriteByteAddress ( tempMemWriteByteAddress )
    , .__tmp_MemData       ( dataToMemory            )
    );

  assign MemWriteByteAddress = (MemWrite == 'b0) ? 4'b0 : tempMemWriteByteAddress;

  // Combinational assignment to MEM_to_WB interface
  assign MEM_to_WB.RegWriteW = EX_to_MEM.RegWrite;
  assign MEM_to_WB.cfsm__result_src = EX_to_MEM.ResultSrc;
  assign MEM_to_WB.rd = EX_to_MEM.rd;
  assign MEM_to_WB.alu_result = EX_to_MEM.alu_result;
  assign MEM_to_WB.pc_plus_4 = EX_to_MEM.pc_plus_4;

endmodule