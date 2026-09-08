`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/timescale.svh"

module extend
  ( input  wire [31:7] instr
  , input  opcode_t opcode
  , output imm_t    imm_ext
  );

  always_comb
    case (opcode)
      OPCODE_OP_IMM, OPCODE_LOAD, OPCODE_JALR:
        imm_ext = {{20{instr[31]}}, instr[31:20]};
      OPCODE_STORE:  imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      OPCODE_BRANCH: imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
      OPCODE_JAL:    imm_ext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
      OPCODE_AUIPC, OPCODE_LUI: imm_ext = {instr[31:12], 12'b0};
      default:       imm_ext = 32'b0;
    endcase

endmodule
