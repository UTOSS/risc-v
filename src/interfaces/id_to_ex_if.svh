`ifndef ID_TO_EX_IF__HG
`define ID_TO_EX_IF__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  alu_src_a_t   alu_src_a;
  alu_src_b_t   alu_src_b;
  result_src_t  result_src;
  addr_t        pc_cur;
  addr_t        pc_plus_4;
  logic         branch;
  logic         jump;
  logic         pc_target_kind;
  logic         mem_write;
  logic         reg_write;
  alu_control_t alu_control;
  logic [2:0]   funct3;
  data_t        rd1;
  data_t        rd2;
  reg_t         rd;
  reg_t         rs1;
  reg_t         rs2;
  imm_t         imm_ext;
`ifdef UTOSS_RISCV__ZICSR_ENABLED
  csr_addr_t    csr_addr;
  logic         csr_write_enable;
  data_t        csr_write_data;
  data_t        csr_read_data;
`endif
`ifdef UTOSS_RISCV_ENABLE_B_EXT
  ext__b__types::b_alu_control_t b_alu_control;
`endif
`ifdef UTOSS_RISCV__MUL_ENABLED
  logic         is_mul;
  ext__m__types::m_mul_control_t mul_control;
`endif
`ifdef UTOSS_RISCV__DIV_ENABLED
  logic         is_div;
  ext__m__types::m_div_control_t div_control;
`endif
} id_to_ex_t;

`endif
