`timescale 1ns / 1ps

module uart #
(
    parameter DATA_WIDTH = 8
    , parameter CLK_HZ = 50000000
    , parameter BAUD = 115200
)
(
    input  wire  clk
    , input  wire  rst
    , input  wire [DATA_WIDTH - 1:0]  i_data_s
    , input  wire  i_valid_s
    , output wire  o_ready_s
    , output wire [DATA_WIDTH - 1:0]  o_data_m
    , output wire o_valid_m
    , input  wire i_ready_m
    , input  wire  i_rxd
    , output wire o_txd
    , output wire  o_tx_busy
    , output wire  o_rx_busy
    , output wire  o_rx_overrun_error
    , output wire o_rx_frame_error
);


// clocks per bit
//localparam integer CLK_HZ = 50000000;
//localparam integer BAUD   = 115200;
localparam int DIV = (CLK_HZ / BAUD);  // 50e6/115200 ≈ 434

uart_tx #(
    .DATA_WIDTH(DATA_WIDTH)
    , .DIV(DIV)
)
uart_tx_inst (
    .clk(clk)
    , .rst(rst)
    , .i_data(i_data_s)
    , .i_valid(i_valid_s)
    , .o_ready(o_ready_s)
    , .o_txd(o_txd)
    , .o_busy(o_tx_busy)
);

uart_rx #(
    .DATA_WIDTH(DATA_WIDTH)
    , .DIV(DIV)
)
uart_rx_inst (
    .clk(clk)
    , .rst(rst)
    , .o_data(o_data_m)
    , .o_valid(o_valid_m)
    , .i_ready(i_ready_m)
    , .i_rxd(i_rxd)
    , .o_busy(o_rx_busy)
    , .o_overrun_error(o_rx_overrun_error)
    , .o_frame_error(o_rx_frame_error)
);


endmodule