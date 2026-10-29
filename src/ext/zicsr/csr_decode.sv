`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

module csr_decode
  ( input  opcode_t                         opcode
  , input  logic [2:0]                      funct3
  , input  logic [4:0]                      rs1_or_uimm
  , input  csr_addr_t                       csr_addr
  , input  data_t                           rs1_data
  , output ext__zicsr__types::csr_request_t csr_request
  );

  import ext__zicsr__types::*;

  logic is_imm;

  assign is_imm = funct3[2];

  always_comb
    if (opcode != OPCODE_SYSTEM)
      csr_request.op = CSR_OP__NONE;
    else
      case (funct3[1:0])
        2'b01:   csr_request.op = CSR_OP__WRITE;
        2'b10:   csr_request.op = CSR_OP__SET;
        2'b11:   csr_request.op = CSR_OP__CLEAR;
        default: csr_request.op = CSR_OP__NONE; // ecall/ebreak/etc.
      endcase

  assign csr_request.valid   = csr_request.op != CSR_OP__NONE;
  assign csr_request.address = csr_addr;
  assign csr_request.operand = is_imm ? data_t'(rs1_or_uimm) : rs1_data;

  // csrrw[i] always writes; csrrs[i]/csrrc[i] do not write when rs1 is x0 / uimm is 0
  assign csr_request.write_intent =
    csr_request.valid && ((csr_request.op == CSR_OP__WRITE) || (rs1_or_uimm != 5'd0));

endmodule
