`timescale 1ns / 1ps

module uart_tx #
(
    parameter DATA_WIDTH = 8,
    parameter DIV = 434 // 50e6/115200 ≈ 434
)
(
    input  wire                   clk,
    input  wire                   rst,
    input  wire [DATA_WIDTH-1:0]  i_data,
    input  wire                   i_valid,
    output logic                  o_ready,
    output logic                  o_txd,
    output logic                  o_busy
);

    // 1 start + DATA_WIDTH data + 1 stop
    localparam integer FRAME_BITS = DATA_WIDTH + 2;

    reg [FRAME_BITS-1:0] data_reg = {FRAME_BITS{1'b1}};
    reg [3:0] bit_idx;
    reg [18:0] timer;

    typedef enum logic {STATE_IDLE, STATE_SEND} uart_tx_state_t;
	 uart_tx_state_t state;

    always @(posedge clk) begin
        if (rst) begin
            o_ready <= 1'b1;
            o_txd <= 1'b1;
            o_busy <= 1'b0;
            data_reg <= {FRAME_BITS{1'b1}};
            bit_idx <= 4'd0;
            timer   <= 19'd0;
            state   <= STATE_IDLE;
        end else begin
            case (state)
                STATE_IDLE: begin
                    o_txd <= 1'b1;
                    o_busy <= 1'b0;
                    o_ready <= 1'b1;

                    if (i_valid) begin
                        data_reg <= {1'b1, i_data, 1'b0};
                        bit_idx <= 4'd0;
                        o_txd <= 1'b0;
                        timer <= DIV - 1;
                        o_busy <= 1'b1;
                        o_ready <= 1'b0;
                        state <= STATE_SEND;
                    end
                end

                STATE_SEND: begin
                    o_busy <= 1'b1;
                    o_ready <= 1'b0;
                    if (timer != 0) begin
                        timer <= timer - 1'b1;
                    end else begin
                        bit_idx <= bit_idx + 1'b1;
                        data_reg <= {1'b1, data_reg[FRAME_BITS-1:1]}; //shift 1 bit so that LSB is the data out
                        o_txd <= data_reg[1];
                        timer <= DIV - 1;
                        if (bit_idx == FRAME_BITS-1) begin
                            state <= STATE_IDLE;
                        end
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
