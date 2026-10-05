`include "src/timescale.svh"
`include "src/headers/types.svh"

module hazard_unit
  ( input logic clk

  , input  reg_t      rs1_e
  , input  reg_t      rs2_e
  , input  reg_t      rd_m
  , input  reg_t      rd_w
  , input  wire reg_write_m
  , input  wire reg_write_w
  , input  result_src_t result_src_e
  , input  reg_t      rs1_d
  , input  reg_t      rs2_d
  , input  reg_t      rd_e
  , input  pc_src_t pc_src_e
`ifdef UTOSS_RISCV__ZICSR_ENABLED
  , input  wire       reg_write_e
  , input  logic      csr_instr_d
  , input  logic      csr_write_intent_e
  , input  logic      csr_write_intent_m
  , input  logic      csr_write_intent_w
  , input  csr_addr_t csr_addr_d
  , input  csr_addr_t csr_addr_e
  , input  csr_addr_t csr_addr_m
  , input  csr_addr_t csr_addr_w
`endif
  , output hazard_forward_a_t forward_a_e
  , output hazard_forward_b_t forward_b_e
  , output logic stall_f
  , output logic stall_d
  , output logic flush_f
  , output logic flush_d
  , output logic flush_e
  );

  // Forwarding: if the operand in EX stage is coming from a prior instruction that is about to
  // write back or finish memory, select the appropriate source instead of using the stale register
  // value. Priority is MEM first, then WB, otherwise keep the original EX operand.
  always_comb
    if ((rs1_e == rd_m) && reg_write_m && (rs1_e != 5'd0))
      forward_a_e = HAZARD_FORWARD_A__MEMORY_ALU_RESULT;
    else if ((rs1_e == rd_w) && reg_write_w && (rs1_e != 5'd0))
      forward_a_e = HAZARD_FORWARD_A__WRITE_BACK_RESULT;
    else
      forward_a_e = HAZARD_FORWARD_A__EXECUTE_RD1;

  always_comb
    if ((rs2_e == rd_m) && reg_write_m && (rs2_e != 5'd0))
      forward_b_e = HAZARD_FORWARD_B__MEMORY_ALU_RESULT;
    else if ((rs2_e == rd_w) && reg_write_w && (rs2_e != 5'd0))
      forward_b_e = HAZARD_FORWARD_B__WRITE_BACK_RESULT;
    else
      forward_b_e = HAZARD_FORWARD_B__EXECUTE_RD2;

  logic lw_stall;

  // Stall on a load-use hazard: if EX is a load and the next instruction reads the loaded register
  // before the result is available, insert a pipeline bubble to avoid using stale data.
  assign lw_stall = (result_src_e == RESULT_SRC__READ_DATA) &&
                    ((rs1_d == rd_e) || (rs2_d == rd_e)) &&
                    (rd_e != 5'd0);

  // leaving this wire in the base-ISA configuration with the expectation that it will get optimized
  // away
  logic csr_stall;

//CSR stall for csr-to-csr stall and rs1 register hazards
`ifdef UTOSS_RISCV__ZICSR_ENABLED
  assign csr_stall =
      csr_instr_d &&
      (((csr_write_intent_e && (csr_addr_d == csr_addr_e)) ||
        (csr_write_intent_m && (csr_addr_d == csr_addr_m)) ||
        (csr_write_intent_w && (csr_addr_d == csr_addr_w))) || // If any of the instructions in EX, MEM, or WB stages are writing to the same CSR as the instruction in ID stage, stall.
       ((rs1_d != 5'd0) &&
        ((reg_write_e && (rs1_d == rd_e)) ||
         (reg_write_m && (rs1_d == rd_m))))); // Write hazard on rs1: if the instruction in ID stage reads rs1 and the instruction in EX or MEM stage is writing to the same register, stall.
`else
  assign csr_stall = 1'b0;
`endif

  assign stall_f = lw_stall || csr_stall;
  assign stall_d = lw_stall || csr_stall;


  //Flush when a control hazard occurs; we need to flush one cycle later than we discover the
  // control hazard; this is due to synchronous memory making the instruction available one cycle
  // later than with async memory
  reg pc_src_e_lag;
  always_ff @ (posedge clk) pc_src_e_lag <= pc_src_e;

  wire control_hazard;
  assign control_hazard = pc_src_e || pc_src_e_lag;

  assign flush_f = control_hazard;
  assign flush_d = control_hazard;
  assign flush_e = lw_stall || csr_stall || control_hazard;

endmodule
