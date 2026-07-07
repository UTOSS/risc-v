`include "src/timescale.svh"
`include "src/headers/types.svh"

// TODO: review all the signal assignments
/* verilator lint_off DECLFILENAME */
module control_fsm
/* verilator lint_off DECLFILENAME */
  ( input opcode_t opcode

  , output var logic        reg_write
  , output result_src_t     result_src
  , output var logic        mem_write
  , output var logic        jump
  , output var logic        branch
  , output pc_target_kind_t pc_target_kind

  , output alu_src_a_t alu_src_a
  , output alu_src_b_t alu_src_b
  );

  always_comb
    reg_write =
      (opcode == JAL) ||
      (opcode == OP) ||
      (opcode == LOAD) ||
      (opcode == OP_IMM) ||
      (opcode == JALR) ||
      (opcode == AUIPC) ||
      (opcode == LUI);

  always_comb
    case (opcode)
      OP, OP_IMM:
        result_src = RESULT_SRC__ALU_RESULT;
      LOAD:
        result_src = RESULT_SRC__READ_DATA;
      JAL, JALR:
        result_src = RESULT_SRC__PC_PLUS_4;
      default:
        result_src = result_src_t'('0);
    endcase

  always_comb mem_write = opcode == STORE;

  always_comb jump = (opcode == JAL) || (opcode == JALR);

  always_comb branch = opcode == BRANCH;

  always_comb
    case (opcode)
      JAL:  pc_target_kind = PC_TARGET_KIND__RELATIVE;
      JALR: pc_target_kind = PC_TARGET_KIND__ABSOLUTE;
      default:    pc_target_kind = pc_target_kind_t'('x);
    endcase

  always_comb
    case (opcode)
      OP, OP_IMM, LOAD, JALR, STORE, BRANCH, LUI /* TODO: triple check lui */:
        alu_src_a = ALU_SRC_A__RD1;
      AUIPC, JAL:
        alu_src_a = ALU_SRC_A__PC;
      default:
        alu_src_a = alu_src_a_t'('x);
    endcase

  always_comb
    case (opcode)
      OP, BRANCH:
        alu_src_b = ALU_SRC_B__RD2;
      AUIPC, LUI, OP_IMM, JALR, LOAD, STORE:
        alu_src_b = ALU_SRC_B__IMM_EXT;
      default:
        alu_src_b = alu_src_b_t'('x);
    endcase
endmodule
