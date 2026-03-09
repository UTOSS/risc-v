module zbb_bitcount #(
    parameter XLEN = 32
)(
    input  logic [XLEN-1:0] value,
    input  logic [1:0] op, // 0 = CLZ, 1 = CTZ, 2 = CPOP
    output logic [$clog2(XLEN+1)-1:0] result //Set Result to the correct size to store a value of max XLEN
);

always_comb begin
    result = '0;

    case (op)

        // CLZ (Count Leading Zeros)
        2'd0: begin
            result = XLEN;

            for (int i = XLEN-1; i >= 0; i--) begin
                if (value[i]) begin
                    result = XLEN-1-i;
                    break;
                end
            end
        end


        // CTZ (Count Trailing Zeros)
        2'd1: begin
            result = XLEN;

            for (int i = 0; i < XLEN; i++) begin
                if (value[i]) begin
                    result = i;
                    break;
                end
            end
        end


        // CPOP (Count Population [a.k.a 1s])
        2'd2: begin
            result = '0;

            for (int i = 0; i < XLEN; i++) begin
                result += value[i];
            end
        end


        default: result = '0;

    endcase
end

endmodule