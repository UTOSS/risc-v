`include "src/headers/types.svh"
`include "src/interfaces/id_to_ex_if.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module Execute
  ( input id_to_ex_t ID_to_EX
  , input wire clk
  , input wire reset
  , output wire zero_flag
  , output data_t alu_result
  , output addr_t pc_target
  , output ex_to_if_t EX_to_IF
  , output ex_to_mem_t EX_to_MEM
  );

  data_t alu_input_b;

  always @(*) begin
    case (ID_to_EX.ALUSrcB)
      ALU_SRC_B__RD2:     alu_input_b = ID_to_EX.rd2;
      ALU_SRC_B__IMM_EXT: alu_input_b = ID_to_EX.imm_ext;
      default:            alu_input_b = 'x;
    endcase
  end

  assign pc_target = ID_to_EX.imm_ext + ID_to_EX.pc_cur;

  ALU alu
    ( .a              ( ID_to_EX.rd1        )
    , .b              ( alu_input_b         )
    , .alu_control    ( ID_to_EX.ALUControl )
    , .out            ( alu_result          )
    , .zeroE          ( zero_flag           )
    );

  assign EX_to_MEM.ResultSrc        = ID_to_EX.ResultSrc;
  // assign EX_to_MEM.AdrSrc = ID_to_EX.AdrSrc;
  // assign EX_to_MEM.pc_src = ID_to_EX.pc_src;
  // assign EX_to_MEM.IRWrite = ID_to_EX.IRWrite;
  // assign EX_to_MEM.MemWriteByteAddress = ID_to_EX.MemWriteByteAddress;
  // assign EX_to_MEM.MemWrite = ID_to_EX.MemWrite;
  assign EX_to_MEM.RegWrite         = ID_to_EX.RegWrite;
  assign EX_to_MEM.funct3           = ID_to_EX.funct3;
  // assign EX_to_MEM.rd2 <= ID_to_EX.rd2;
  assign EX_to_MEM.rd               = ID_to_EX.rd;
  assign EX_to_MEM.alu_result       = alu_result;
  assign EX_to_MEM.pc_cur           = ID_to_EX.pc_cur;
  assign EX_to_IF.imm_ext           = ID_to_EX.imm_ext;
  assign EX_to_IF.pc_src            = ID_to_EX.pc_src;
  assign EX_to_IF.alu_result_for_pc = alu_result;
  assign EX_to_IF.pc_old            = ID_to_EX.pc_cur;

endmodule
