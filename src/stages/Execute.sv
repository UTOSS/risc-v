`include "src/headers/types.svh"
`include "src/packages/pkg_hazard_unit.svh"
`include "src/interfaces/id_to_ex_if.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

import pkg_hazard_unit::*;

module Execute
  ( input id_to_ex_t ID_to_EX
  , input wire clk
  , input wire reset

  , input forward_a_t hz_forward_a
  , input forward_b_t hz_forward_b

  , input data_t wb_result
  , input data_t mem_alu_result

  , output wire zero_flag
  , output data_t alu_result
  , output addr_t pc_target
  , output ex_to_if_t EX_to_IF
  , output ex_to_mem_t EX_to_MEM
  );

  data_t alu_input_a;
  data_t alu_input_b;
  data_t safe_rd2; // hazard-safe version of rd2
  data_t WriteDataE;

  logic JumpE;
  logic BranchE;
  

  assign JumpE = ID_to_EX.Jump;
  assign BranchE = ID_to_EX.Branch;

  always_comb
    case (hz_forward_a)
      FORWARD_A__EXECUTE_RD1:       alu_input_a = ID_to_EX.rd1;
      FORWARD_A__WRITE_BACK_RESULT: alu_input_a = wb_result;
      FORWARD_A__MEMORY_ALU_RESULT: alu_input_a = mem_alu_result;
      default:                      alu_input_a = 'x;
    endcase

  always_comb
    case (hz_forward_b)
      FORWARD_B__EXECUTE_RD2:       safe_rd2 = ID_to_EX.rd2;
      FORWARD_B__WRITE_BACK_RESULT: safe_rd2 = wb_result;
      FORWARD_B__MEMORY_ALU_RESULT: safe_rd2 = mem_alu_result;
      default:                      safe_rd2 = 'x;
    endcase

  always_comb
    case (ID_to_EX.ALUSrcB)
      EXECUTE_ALU_SRC_B__RD2:     alu_input_b = safe_rd2;
      EXECUTE_ALU_SRC_B__IMM_EXT: alu_input_b = ID_to_EX.imm_ext;
      default:                    alu_input_b = 'x;
    endcase

  assign pc_target = ID_to_EX.imm_ext + ID_to_EX.pc_cur;

  ALU alu
    ( .a              ( alu_input_a         )
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
  assign EX_to_MEM.MemWrite         = ID_to_EX.MemWrite;
  assign EX_to_MEM.RegWrite         = ID_to_EX.RegWrite;
  // assign EX_to_MEM.funct3           = ID_to_EX.funct3;
  assign EX_to_MEM.WriteDataE       = safe_rd2;
  // assign EX_to_MEM.rd2 <= ID_to_EX.rd2;
  assign EX_to_MEM.rd               = ID_to_EX.rd;
  assign EX_to_MEM.alu_result       = alu_result;
  assign EX_to_MEM.pc_cur           = ID_to_EX.pc_cur;
  assign EX_to_IF.imm_ext           = ID_to_EX.imm_ext;
  assign EX_to_IF.pc_src            = (JumpE | (zero_flag & BranchE)) ? PC_SRC__ALU_RESULT: PC_SRC__INCREMENT;
  assign EX_to_IF.alu_result_for_pc = alu_result;
  assign EX_to_IF.pc_old            = ID_to_EX.pc_cur;
  assign EX_to_IF.pc_plus_4         = ID_to_EX.pc_plus_4;

endmodule
