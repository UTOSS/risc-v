module inst_mem #(
    parameter ADDR_W = 12 
)(
    input  wire             clk,
    input  wire             we,
    input  wire [ADDR_W-1:0] addr,
    input  wire [7:0]       wdata,
    output reg  [7:0]       rdata
);
    reg [7:0] mem [0:(1<<ADDR_W)-1];

    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
        rdata <= mem[addr];  
    end
endmodule
