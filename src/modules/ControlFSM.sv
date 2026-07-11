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
      (opcode == OPCODE_JAL) ||
      (opcode == OPCODE_OP) ||
      (opcode == OPCODE_LOAD) ||
      (opcode == OPCODE_OP_IMM) ||
      (opcode == OPCODE_JALR) ||
      (opcode == OPCODE_AUIPC) ||
      (opcode == OPCODE_LUI);

  always_comb
    case (opcode)
      OPCODE_OP, OPCODE_OP_IMM:
        result_src = RESULT_SRC__ALU_RESULT;
      OPCODE_LOAD:
        result_src = RESULT_SRC__READ_DATA;
      OPCODE_JAL, OPCODE_JALR:
        result_src = RESULT_SRC__PC_PLUS_4;
      default:
        result_src = result_src_t'('0);
    endcase

  always_comb mem_write = opcode == OPCODE_STORE;

  always_comb jump = (opcode == OPCODE_JAL) || (opcode == OPCODE_JALR);

  always_comb branch = opcode == OPCODE_BRANCH;

  always_comb
    case (opcode)
      OPCODE_JAL:  pc_target_kind = PC_TARGET_KIND__RELATIVE;
      OPCODE_JALR: pc_target_kind = PC_TARGET_KIND__ABSOLUTE;
      default:    pc_target_kind = pc_target_kind_t'('x);
    endcase

  always_comb
    case (opcode)
      OPCODE_OP, OPCODE_OP_IMM, OPCODE_LOAD, OPCODE_JALR, OPCODE_STORE, OPCODE_BRANCH, OPCODE_LUI /* TODO: triple check lui */:
        alu_src_a = ALU_SRC_A__RD1;
      OPCODE_AUIPC, OPCODE_JAL:
        alu_src_a = ALU_SRC_A__PC;
      default:
        alu_src_a = alu_src_a_t'('x);
    endcase

  always_comb
    case (opcode)
      OPCODE_OP, OPCODE_BRANCH:
        alu_src_b = ALU_SRC_B__RD2;
      OPCODE_AUIPC, OPCODE_LUI, OPCODE_OP_IMM, OPCODE_JALR, OPCODE_LOAD, OPCODE_STORE:
        alu_src_b = ALU_SRC_B__IMM_EXT;
      default:
        alu_src_b = alu_src_b_t'('x);
    endcase
endmodule
