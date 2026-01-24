`timescale 1ns / 1ps

module uart_rx #
(
    parameter DATA_WIDTH = 8
    , parameter DIV = 434 // 50e6/115200 ≈ 434
)
(
    input  wire    clk
    , input  wire    rst
    , output logic [DATA_WIDTH - 1:0]  o_data
    , output logic o_valid
    , input  wire i_ready
    , input  wire i_rxd
    , output logic                  o_busy
    , output logic                  o_overrun_error
    , output logic                  o_frame_error
);

    reg rxd_q0;
    reg rxd_q1;

    // detect falling edge
    reg rxd_q1_d = 1'b1;
    wire start_fall = (rxd_q1_d == 1'b1) && (rxd_q1 == 1'b0);

    typedef enum logic [1:0] {
    STATE_IDLE  = 2'd0, 
    STATE_START = 2'd1, 
    STATE_DATA  = 2'd2, 
    STATE_STOP  = 2'd3
	 } uart_state_t;
    uart_state_t  state = STATE_IDLE;

    reg [18:0] timer;
    reg [3:0]  bit_idx;
    reg [DATA_WIDTH-1:0] data_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            o_data  <= 0;
            o_valid <= 0;
            o_busy <= 0;
            o_overrun_error <= 0;
            o_frame_error   <= 0;
            rxd_q0   <= 1'b1;
            rxd_q1   <= 1'b1;
            rxd_q1_d <= 1'b1;
            state <= STATE_IDLE;
            timer <= 0;
            bit_idx <= 0;
            data_reg <= 0;
        end else begin
            // 2FF synchronizer because aynchronous input
            rxd_q0 <= i_rxd;
            rxd_q1 <= rxd_q0;
            rxd_q1_d <= rxd_q1;
            o_overrun_error <= 1'b0;
            o_frame_error <= 1'b0;

            if (o_valid && i_ready) begin
                o_valid <= 1'b0;
            end

            case (state)
                STATE_IDLE: begin
                    o_busy <= 1'b0;
                    bit_idx <= 0;
                    timer <= 0;

                    if (start_fall) begin
                        o_busy <= 1'b1;
                        state    <= STATE_START;
                        timer    <= (DIV / 2) - 1; // center
                    end
                end

                STATE_START: begin
                    o_busy <= 1'b1;
                    if (timer != 0) begin
                        timer <= timer - 1'b1;
                    end else begin
                        if (rxd_q1 == 1'b0) begin
                            state         <= STATE_DATA;
                            bit_idx    <= 0;
                            data_reg <= 0;
                            timer      <= DIV - 1; 
                        end else begin
                            ///starting bit not 0, error
                            state <= STATE_IDLE;
									 o_frame_error <= 1'b1;
                        end
                    end
                end

                STATE_DATA: begin
                    o_busy <= 1'b1;
                    if (timer != 0) begin
                        timer <= timer - 1'b1;
                    end else begin
                        data_reg[bit_idx] <= rxd_q1; // LSB first

                        if (bit_idx == DATA_WIDTH-1) begin
                            state    <= STATE_STOP;
                            timer <= DIV - 1;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                            timer   <= DIV - 1;
                        end
                    end
                end

                STATE_STOP: begin
                    o_busy <= 1'b1;
                    if (timer != 0) begin
                        timer <= timer - 1'b1;
                    end else begin
                        // stop bit should be 1
                        if (rxd_q1 == 1'b1) begin
                            o_data  <= data_reg;
                            o_overrun_error <= o_valid; // previous data is still there
                            o_valid <= 1'b1;
                        end else begin
                            o_frame_error <= 1'b1;
                        end
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
