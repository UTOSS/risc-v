`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  alu_src_a_t  ALUSrcA;
  alu_src_b_t  ALUSrcB;
  result_src_t ResultSrc;
  adr_src_t    AdrSrc;
  logic        pc_update;
  pc_src_t     pc_src;
  addr_t       pc_cur;
  logic        IRWrite;
  logic        Branch;
  logic [3:0]  MemWriteByteAddress;
  logic [4:0]  FSMState;
  logic [3:0]  MemWrite;
  logic        RegWrite;
  logic [3:0]  ALUControl;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  data_t       rd1;
  data_t       rd2;
  logic [4:0]  rd;
  logic [4:0]  rs1;
  logic [4:0]  rs2;
  imm_t        imm_ext;
} id_to_ex_t;
