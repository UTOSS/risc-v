`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module fetch_stage
  ( output if_to_id_t IF_to_ID
  , input ex_to_if_t  EX_to_IF

  , input wire clk
  , input wire reset

  , output addr_t imem__address
  , input data_t imem__data
);
  addr_t pc_cur;

  always @ (posedge clk)
    if (reset)
      pc_cur <= 0;
    else
      pc_cur <= imem__address;

  always @ (posedge clk)
    case (EX_to_IF.pc_src)
      PC_SRC__INCREMENT:  imem__address <= pc_cur + 32'h4;
      PC_SRC__JUMP:       imem__address <= EX_to_IF.pc_old + EX_to_IF.imm_ext;
      PC_SRC__ALU_RESULT: imem__address <= {EX_to_IF.alu_result_for_pc[31:1], 1'b0};
    endcase

  assign IF_to_ID.instruction = imem__data;
  assign IF_to_ID.pc_cur = pc_cur;
endmodule
