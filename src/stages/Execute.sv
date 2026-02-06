`include "src/headers/types.svh"

module Execute
  ( id_to_ex_if.Execute ID_to_EX
  , input wire clk
  , input wire reset
  , input addr_t inPCPlus4E
  , output addr_t outPCPlus4E
  , output wire zero_flag
  , output data_t alu_result
  , output addr_t pc_target
  , ex_to_mem_if.Execute EX_to_MEM
  );

  data_t alu_input_b;

  always @(*) begin
    case (ID_to_EX.ALUSrcB)
      ALU_SRC_B__RD2:     alu_input_b = ID_to_EX.rd2;
      ALU_SRC_B__IMM_EXT: alu_input_b = ID_to_EX.imm_ext;
      default:            alu_input_b = 'x;
    endcase
  end

  assign pc_target = ID_to_EX.imm_ext + inPCPlus4E;

  ALU alu
    ( .a              ( ID_to_EX.rd1        )
    , .b              ( alu_input_b         )
    , .alu_control    ( ID_to_EX.ALUControl )
    , .out            ( alu_result          )
    , .zeroE          ( zero_flag           )
    );

  assign outPCPlus4E = inPCPlus4E;

    always @(posedge clk)
    if (reset) begin
        EX_to_MEM.ResultSrc <= 'b0;
        // EX_to_MEM.AdrSrc <= 'b0;
        // EX_to_MEM.pc_src <= 'b0;
        // EX_to_MEM.IRWrite <= 'b0;
        // EX_to_MEM.MemWriteByteAddress <= 'b0;
        EX_to_MEM.MemWrite <= 'b0;
        EX_to_MEM.RegWrite <= 'b0;
        EX_to_MEM.funct3 <= 'b0;
        // EX_to_MEM.rd2 <= 'b0;
        EX_to_MEM.rd <= 'b0;
        EX_to_MEM.alu_result <= 'b0;
    end
    else begin
        EX_to_MEM.ResultSrc <= ID_to_EX.ResultSrc;
        // EX_to_MEM.AdrSrc <= ID_to_EX.AdrSrc;
        // EX_to_MEM.pc_src <= ID_to_EX.pc_src;
        // EX_to_MEM.IRWrite <= ID_to_EX.IRWrite;
        // EX_to_MEM.MemWriteByteAddress <= ID_to_EX.MemWriteByteAddress;
        EX_to_MEM.MemWrite <= ID_to_EX.MemWrite;
        EX_to_MEM.RegWrite <= ID_to_EX.RegWrite;
        EX_to_MEM.funct3 <= ID_to_EX.funct3;
        // EX_to_MEM.rd2 <= ID_to_EX.rd2;
        EX_to_MEM.rd <= ID_to_EX.rd;
        EX_to_MEM.alu_result <= alu_result;
    end

endmodule