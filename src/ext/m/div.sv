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
    , output logic [31:0] result_o // dividend / divisor
    , output logic ready_o
    , output logic busy_o
);

    logic [31:0] dividend;
    logic [31:0] divisor;


    // pre-processing

    logic signed_op, dividend_neg, divisor_neg, quot_neg, rem_neg;
    logic [31:0] dividend_abs, divisor_abs;
    logic [1:0] op;
    logic special;

    logic [32:0] rem_q;
    logic [31:0] quot_q;
    logic [31:0] divisor_q;
    logic [5:0] count;

    // FSM definitions
    localparam IDLE = 4'd0,
                LOAD = 4'd1,
                ITER = 4'd2,
                CORRECT = 4'd3,
                FINISH = 4'd4;

    logic [3:0] state = IDLE;

    logic [32:0] rem_sh;
    logic [31:0] quot_sh;
    logic [32:0] diff;
    logic [32:0] quote;
    logic [32:0] rem;

    always_comb begin
        signed_op = (op == 2'b00) | (op == 2'b10);
        dividend_neg = signed_op & dividend[31];
        divisor_neg  = signed_op & divisor[31];
        dividend_abs = dividend_neg ? -dividend : dividend;
        divisor_abs = divisor_neg  ? -divisor : divisor;
        quot_neg = dividend_neg ^ divisor_neg;
        rem_neg = dividend_neg;  // remainder takes the dividend's sign

        busy_o = (state != IDLE);
        ready_o = (state == FINISH);
        special = (divisor == 32'd0) | (signed_op & (dividend == 32'h8000_0000) & (divisor == 32'hFFFF_FFFF));

        // shift registers
        rem_sh = {rem_q[31:0], quot_q[31]};   // top dividend bit in
        quot_sh = {quot_q[30:0], 1'b0};
        diff = rem_sh - {1'b0, divisor_q};
   
    end

    always_ff @(posedge clk) begin

        if (~rst_n) begin
            dividend <= 32'b0;
            divisor <= 32'b0;
            op <= 2'b0;
            state <= IDLE;
        end

        else case (state)

            IDLE: begin
                if (start_i)  begin
                    state <= LOAD;
                    dividend <= rs1_i;
                    divisor <= rs2_i;
                    op <= op_i;
                end 
            end
            LOAD: begin
                rem_q <= 0;
                quot_q <= dividend_abs;
                divisor_q <= divisor_abs;
                count <= 31;

                state <= ITER;
                if (special) state <= FINISH;
            end
            ITER: begin
                
                rem_sh = {rem_q[31:0], quot_q[31]}; // shift the remainder & quotient
                quot_sh = {quot_q[30:0], 1'b0};
                diff = rem_sh - {1'b0, divisor_q}; // perform subtraction, 33 bit
                // keep the difference or restore?
                rem_q  <= ~diff[32] ? diff : rem_sh;
                quot_q <= ~diff[32] ? (quot_sh | 32'd1) : quot_sh;

                count <= count - 1;

                if (count == 0) state <= CORRECT;
                
            end
            CORRECT: begin
                quot = quot_neg ? -quot_q : quot_q;
                rem = rem_neg ? -rem_q[31:0] : rem_q[31:0];
                result_o = op[1] ? rem : quot;
                state <= FINISH;
            end
            FINISH: begin
                state <= IDLE;
            end

            default: state <= IDLE;

        endcase
    end

endmodule
