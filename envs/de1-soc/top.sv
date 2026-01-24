module top (
    input  wire CLOCK_50
    , input  wire [3:0]  KEY
    , output wire [9:0]  LEDR
    , input  wire  UART_TX
    , output wire  UART_RX    // FPGA->PC (txd)
);

    wire rst = ~KEY[0];

    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    wire       uart_rx_ready;

    wire [7:0] uart_tx_data;
    wire       uart_tx_valid;
    wire       uart_tx_ready;

    wire       tx_busy, rx_busy, rx_overrun, rx_frame;

    uart  #(
            .DATA_WIDTH(8)
            , .CLK_HZ(50000000)
            , .BAUD(115200)
    )
    u_uart (
        .clk(CLOCK_50)
        , .rst(rst)
        , .i_data_s(uart_tx_data)
        , .i_valid_s(uart_tx_valid)
        , .o_ready_s(uart_tx_ready)
        , .o_data_m(uart_rx_data)
        , .o_valid_m(uart_rx_valid)
        , .i_ready_m(uart_rx_ready)
        , .i_rxd(UART_TX)
        , .o_txd(UART_RX)
        , .o_tx_busy(tx_busy)
        , .o_rx_busy(rx_busy)
        , .o_rx_overrun_error(rx_overrun)
        , .o_rx_frame_error(rx_frame)
    );


    logic [31:0] dbg_addr, dbg_write_data;
    logic [3:0]  dbg_write_enable;
    wire [31:0]  read_data;

    logic hold_core;

    uart_bus_master u_master (
        .clk(CLOCK_50)
        , .rst(rst)
        , .rx_data(uart_rx_data)
        , .rx_valid(uart_rx_valid)
        , .rx_ready(uart_rx_ready)
        , .tx_data(uart_tx_data)
        , .tx_valid(uart_tx_valid)
        , .tx_ready(uart_tx_ready)
        , .bus_addr(dbg_addr)
        , .bus_write_data(dbg_write_data)
        , .bus_write_enable(dbg_write_enable)
        , .bus_read_data(read_data)
        , .dbg_regs(dbg_regs)
        , .dbg_pc(dbg_pc)
        , .hold_core(hold_core)
    );

    addr_t core_addr;
    data_t core_write_data;
    logic [3:0] core_write_enable;

    logic [31:0] dbg_regs [0:31];
    addr_t       dbg_pc;

    wire core_reset = rst | hold_core;

    addr_t bus_addr;
    data_t bus_write_data;
    logic [3:0] bus_write_enable;

    assign bus_addr  = hold_core ? dbg_addr  : core_addr;
    assign bus_write_data = hold_core ? dbg_write_data : core_write_data;
    assign bus_write_enable = hold_core ? dbg_write_enable : core_write_enable;

    memory_map #( 
           .SIZE(512) 
    )
    u_mem (
        .clk(CLOCK_50)
        , .address(bus_addr)
        , .write_data(bus_write_data)
        , .write_enable(bus_write_enable)
        , .read_data(read_data)
        , .dbg_regs(dbg_regs)
        , .dbg_pc(dbg_pc)
        , .LEDR(LEDR)
    );

    utoss_riscv core (
        .clk(CLOCK_50)
        , .reset(core_reset)
        , .memory__address(core_addr)
        , .memory__write_data(core_write_data)
        , .memory__write_enable(core_write_enable)
        , .memory__read_data(read_data)
        , .dbg_regs(dbg_regs)
        , .dbg_pc(dbg_pc)
    );

endmodule
