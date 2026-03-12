`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module fetch_stage
  ( output if_to_id_t IF_to_ID
  , input ex_to_if_t  EX_to_IF

  , input wire clk
  , input wire reset
  , input wire StallF

  , output addr_t imem__address
  , input data_t imem__data
);
  // Decode needs to end up getting the same address as was given to imemory.
  // At the start of the clock cycle, we need to indicate to decode the address
  // and content of the previous instruction, while telling memory the address
  // of the next instruction.
  addr_t pc_previous;
  addr_t pc_next;

  always_comb
    case (EX_to_IF.pc_src)
      PC_SRC__INCREMENT:  pc_next = pc_previous + 32'h4;
      PC_SRC__JUMP:       pc_next = EX_to_IF.pc_old + EX_to_IF.imm_ext;
      PC_SRC__ALU_RESULT: pc_next = {EX_to_IF.alu_result_for_pc[31:1], 1'b0};
      default:            pc_next = 32'hx;
    endcase

  always @ (posedge clk)
    if (!StallF) pc_previous <= reset ? 0 : pc_next;

  assign imem__address = pc_next;
  assign IF_to_ID.instruction = imem__data;
  assign IF_to_ID.pc_cur = pc_previous;
  assign IF_to_ID.pc_plus_4 = pc_previous + 32'h4;
endmodule
