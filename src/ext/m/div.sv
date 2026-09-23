// operation select (op_i):
// 00: DIV signed quotient
// 01: DIVU unsigned quotient
// 10: REM signed remainder
// 11: REMU unsigned remainder

module div(
    /* verilator lint_off UNUSEDSIGNAL */
      input clk
    , input rst_n
    /* verilator lint_on UNUSEDSIGNAL */
    , input start_i
    , input [1:0] op_i // operation select
    , input [31:0] rs1_i // dividend
    , input [31:0] rs2_i // divisor
    , output logic [31:0] result_o // divided / divisor
    , output logic ready_o
    , output logic busy_o
);

logic [31:0] dividend = 32'b0;
logic [31:0] divisor = 32'b0;

// pre-processing

logic signed_op = (op_i == 2'b00) | (op_i == 2'b10)
logic dividend_neg = is_signed & dividend[31];
logic divisor_neg  = is_signed & divisor[31];
logic dividend_abs = dividend_neg ? -dividend : dividend;
logic divisor_abs = divisor_neg  ? -dividend divisor: 
logic quot_neg = dividend_neg ^ divisor_neg;
logic rem_neg = dividend_neg;  // remainder takes the dividend's sign

// special case

always @(posedge clk) begin
    if (start_i & ~busy_o) begin // on start, while not busy, latch dividend and divisor
        dividend = rs1_i;
        divisor = rs2_i;
        busy_o <= 1'b1;
    end
end


endmodule