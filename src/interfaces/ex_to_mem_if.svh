`ifndef EX_TO_MEM_IF__HG
`define EX_TO_MEM_IF__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  logic        reg_write;
  mem_op_t     mem_op;
  logic        mem_write;
  result_src_t result_src;
  data_t       alu_result;
  data_t       write_data_e;
  logic [2:0]  funct3;
  reg_t        rd;
  addr_t       pc_cur;
  addr_t       pc_plus_4;
`ifdef UTOSS_RISCV__ZICSR_ENABLED
  csr_addr_t   csr_addr;
  logic        csr_write_enable;
  data_t       csr_write_data;
  data_t       csr_read_data;
`endif
`ifdef UTOSS_RISCV__A_ENABLED
  // consumed by the A extension's memory-stage FSM; `alu_result` carries the address (rs1 + 0) and
  // `write_data_e` the operand for SC/AMO
  ext__a__types::a_op_t a_op;
  logic        a_aq;
  logic        a_rl;
`endif
} ex_to_mem_t;

`endif
