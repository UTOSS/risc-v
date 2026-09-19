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
  , output mem_op_t         mem_op
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
      (opcode == OPCODE_LUI)
`ifdef UTOSS_RISCV__A_ENABLED
      // every atomic writes rd: the loaded word for `lr.w`, the success code for `sc.w`, the
      // pre-modification value for an AMO
      || (opcode == OPCODE_AMO)
`endif
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      || ((opcode == OPCODE_SYSTEM) && (funct3 inside {3'b001, 3'b010, 3'b011, 3'b101, 3'b110, 3'b111}))
`endif
;

  always_comb
    case (opcode)
      OPCODE_OP, OPCODE_OP_IMM:
        result_src = RESULT_SRC__ALU_RESULT;
      OPCODE_LOAD:
        result_src = RESULT_SRC__READ_DATA;
      OPCODE_JAL, OPCODE_JALR:
        result_src = RESULT_SRC__PC_PLUS_4;
`ifdef UTOSS_RISCV__A_ENABLED
      OPCODE_AMO:
        result_src = RESULT_SRC__ATOMIC;
`endif
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      OPCODE_SYSTEM:
        if (funct3 inside {3'b001, 3'b010, 3'b011, 3'b101, 3'b110, 3'b111})
          result_src = RESULT_SRC__CSR_READ;
        else
          result_src = result_src_t'('0);
`endif
      default:
        result_src = result_src_t'('0);
    endcase

  always_comb
    case (opcode)
      OPCODE_LOAD:  mem_op = MEM_OP__READ;
      OPCODE_STORE: mem_op = MEM_OP__WRITE;
`ifdef UTOSS_RISCV__A_ENABLED
      OPCODE_AMO:   mem_op = MEM_OP__ATOMIC;
`endif
      default:      mem_op = MEM_OP__NONE;
    endcase

  // `mem_write` is derived from `mem_op` so that there is a single place where the memory
  // behaviour of an opcode is decided
  //
  // TODO: retire this signal once the memory stage keys its byte-enable generation off `mem_op`
  // directly (part of the A extension memory-stage FSM work)
  always_comb mem_write = mem_op == MEM_OP__WRITE;

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
`ifdef UTOSS_RISCV__A_ENABLED
      // atomics address memory with the bare rs1 value: there is no offset field in the encoding,
      // so the ALU computes rs1 + 0 purely to hand the address to the memory stage; the actual
      // read-modify-write is done there, not here
      OPCODE_AMO:
        alu_src_a = ALU_SRC_A__RD1;
`endif
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      OPCODE_SYSTEM:
        alu_src_a = ALU_SRC_A__RD1;
`endif
      default:
        alu_src_a = alu_src_a_t'('x);
    endcase

  always_comb
    case (opcode)
      OPCODE_OP, OPCODE_BRANCH:
        alu_src_b = ALU_SRC_B__RD2;
      OPCODE_AUIPC, OPCODE_LUI, OPCODE_OP_IMM, OPCODE_JALR, OPCODE_LOAD, OPCODE_STORE:
        alu_src_b = ALU_SRC_B__IMM_EXT;
`ifdef UTOSS_RISCV__A_ENABLED
      // the instruction decoder forces imm_ext to 0 for atomics, giving rs1 + 0
      OPCODE_AMO:
        alu_src_b = ALU_SRC_B__IMM_EXT;
`endif
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      OPCODE_SYSTEM:
        alu_src_b = ALU_SRC_B__IMM_EXT;
`endif
      default:
        alu_src_b = alu_src_b_t'('x);
    endcase

  // Keep funct3 referenced for lint when CSR decode is compiled out.
  wire unused_funct3 = &{1'b0, funct3};
endmodule
