module MA (
    #(
        parameter SIZE = 1024
    )
    input [31:0] A,
    input [31:0] WD,
    input WE,
    input CLK,
    output [31:0] RD
);

    reg [31:0] M[0:SIZE-1];

    assign RD = M[A[31:2]]; // 2 LSBs used for byte addressing

    always @(posedge CLK) begin
        if (WE) begin
            M[A[31:2]] <= WD;
        end
    end
    
endmodule