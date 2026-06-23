`include "src/timescale.svh"
`include "src/headers/types.svh"

module hazard_unit
  ( input logic clk

  , input  wire [4:0] rs1_e
  , input  wire [4:0] rs2_e
  , input  wire [4:0] rd_m
  , input  wire [4:0] rd_w
  , input  wire reg_write_m
  , input  wire reg_write_w
  , input  result_src_t result_src_e
  , input  wire [4:0] rs1_d
  , input  wire [4:0] rs2_d
  , input  wire [4:0] rd_e
  , input  pc_src_t pc_src_e
  , output hazard_forward_a_t forward_a_e
  , output hazard_forward_b_t forward_b_e
  , output logic stall_f
  , output logic stall_d
  , output logic flush_f
  , output logic flush_d
  , output logic flush_e
  );

  // Forwarding
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

  //Stall when a load hazard occurs
  assign lw_stall =
    (result_src_e == RESULT_SRC__READ_DATA) &&
    ((rs1_d == rd_e) || (rs2_d == rd_e)) &&
    (rd_e != 5'd0);
  assign stall_f = lw_stall;
  assign stall_d = lw_stall;

  //Flush when a control hazard occurs; we need to flush one cycle later than we discover the
  // control hazard; this is due to synchronous memory making the instruction available one cycle
  // later than with async memory
  reg pc_src_e_lag;
  always_ff @ (posedge clk) pc_src_e_lag <= pc_src_e;

  wire control_hazard;
  assign control_hazard = pc_src_e || pc_src_e_lag;

  assign flush_f = control_hazard;
  assign flush_d = control_hazard;
  assign flush_e = lw_stall || control_hazard;

endmodule
