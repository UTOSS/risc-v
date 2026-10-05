module mul(
    /* verilator lint_off UNUSEDSIGNAL */
      input clk
    , input rst_n
    /* verilator lint_on UNUSEDSIGNAL */
    , input start_i
    , input [31:0] rs1_i
    , input [31:0] rs2_i
    , input [1:0] op_i
    , output logic [31:0] result_o
    , output logic ready_o
);

assign ready_o = start_i;

logic rs1_signed;
logic rs2_signed;

assign rs1_signed = (op_i == 2'b01 || op_i == 2'b10) ? 1'b1 : 1'b0;
assign rs2_signed = (op_i == 2'b01) ? 1'b1 : 1'b0;

logic signed [32:0] rs1_signed_ext;
logic signed [32:0] rs2_signed_ext;


assign rs1_signed_ext = (rs1_signed) ? {rs1_i[31], rs1_i} : {1'b0, rs1_i};
assign rs2_signed_ext = (rs2_signed) ? {rs2_i[31], rs2_i} : {1'b0, rs2_i};

logic signed [63:0] product;
assign product = $signed(rs1_signed_ext) * $signed(rs2_signed_ext);

assign result_o = (op_i == 2'b00) ? product[31:0] : product[63:32];


endmodule
