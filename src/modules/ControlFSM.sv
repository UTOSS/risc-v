`include "src/timescale.svh"
`include "src/headers/types.svh"

// TODO: review all the signal assignments
/* verilator lint_off DECLFILENAME */
module control_fsm
/* verilator lint_off DECLFILENAME */
  ( input opcode_t opcode
  , input logic [2:0] funct3

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
      (opcode == JType) ||
      (opcode == RType) ||
      (opcode == IType_load) ||
      (opcode == IType_logic) ||
      (opcode == IType_jalr) ||
      (opcode == UType_auipc) ||
      (opcode == UType_lui)
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      || ((opcode == SYSTEM) && (funct3 inside {3'b001, 3'b010, 3'b011}))
`endif
      ;

  always_comb
    case (opcode)
      RType, IType_logic:
        result_src = RESULT_SRC__ALU_RESULT;
      IType_load:
        result_src = RESULT_SRC__READ_DATA;
      JType, IType_jalr:
        result_src = RESULT_SRC__PC_PLUS_4;
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      SYSTEM:
        if (funct3 inside {3'b001, 3'b010, 3'b011})
          result_src = RESULT_SRC__CSR_READ;
        else
          result_src = result_src_t'('0);
`endif
      default:
        result_src = result_src_t'('0);
    endcase

  always_comb mem_write = opcode == SType;

  always_comb jump = (opcode == JType) || (opcode == IType_jalr);

  always_comb branch = opcode == BType;

  always_comb
    case (opcode)
      JType:      pc_target_kind = PC_TARGET_KIND__RELATIVE;
      IType_jalr: pc_target_kind = PC_TARGET_KIND__ABSOLUTE;
      default:    pc_target_kind = pc_target_kind_t'('x);
    endcase

  always_comb
    case (opcode)
      RType, IType_logic, IType_load, IType_jalr, SType, BType, UType_lui /* TODO: triple check lui */:
        alu_src_a = ALU_SRC_A__RD1;
      UType_auipc, JType:
        alu_src_a = ALU_SRC_A__PC;
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      SYSTEM:
        alu_src_a = ALU_SRC_A__RD1;
`endif
      default:
        alu_src_a = alu_src_a_t'('x);
    endcase

  always_comb
    case (opcode)
      RType, BType:
        alu_src_b = ALU_SRC_B__RD2;
      UType_auipc, UType_lui, IType_logic, IType_jalr, IType_load, SType:
        alu_src_b = ALU_SRC_B__IMM_EXT;
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      SYSTEM:
        alu_src_b = ALU_SRC_B__IMM_EXT;
`endif
      default:
        alu_src_b = alu_src_b_t'('x);
    endcase
endmodule
