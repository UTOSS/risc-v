module ram_m10k #(
    parameter SIZE = 512
)(
    input  wire        clk,
    input  wire [31:0] wdata,
    input  wire  [3:0] we,
    input  wire [31:0] addr,
    output wire [31:0] rdata
);

    altsyncram #(
        .operation_mode("SINGLE_PORT"),
        .width_a(32),
        .widthad_a($clog2(SIZE)),
        .numwords_a(SIZE),
        .outdata_reg_a("UNREGISTERED"),
        .power_up_uninitialized("FALSE"),
        .read_during_write_mode_port_a("DONT_CARE")
    ) ram_inst (
        .clock0(clk),
        .address_a(addr[$clog2(SIZE)-1:0]),
        .data_a(wdata),
        .wren_a(|we),
        .q_a(rdata)
    );

endmodule