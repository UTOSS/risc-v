module aes_coprocessor (
    input  wire        clk,
    input  wire        rst_n,
//MMIO like interface
    input  wire        we,
    input  wire        re,
    input  wire [7:0]  addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output wire        ready
);

assign ready = 1'b1;

reg [31:0] state0, state1, state2, state3;
reg [31:0] rk0, rk1, rk2, rk3;
reg [3:0]  round;

reg [31:0] out0, out1, out2, out3;

reg        start;
reg [1:0]  op;
reg        final_round;

reg busy;
reg done;

wire [127:0] state_in = {state3, state2, state1, state0};
wire [127:0] rk_in    = {rk3, rk2, rk1, rk0};

wire [127:0] state_next;
wire [127:0] rk_next;

aes_round u_aesenc (
    .state_in(state_in),
    .round_key(rk_in),
    .final_round(final_round),
    .state_out(state_next)
);

aes_key_schedule u_aeskey (
    .key_in(rk_in),
    .round(round),
    .key_out(rk_next)
);

always @(*) begin
    rdata = 32'h0;
    if (re) begin
        case (addr)
            default: rdata = 32'h0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state0 <= 0; state1 <= 0; state2 <= 0; state3 <= 0;
        rk0    <= 0; rk1    <= 0; rk2    <= 0; rk3    <= 0;
        round  <= 0;
        out0   <= 0; out1   <= 0; out2   <= 0; out3   <= 0;
        start  <= 0;
        op     <= 0;
        final_round <= 0;
        busy   <= 0;
        done   <= 0;
    end else begin
        start <= 0;

        if (we) begin
            case (addr)
                default: ;
            endcase
        end

//the FSM


    end
end

endmodule