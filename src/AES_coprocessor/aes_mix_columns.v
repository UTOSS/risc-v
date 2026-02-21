module aes_mixcolumns (
    input  wire [127:0] in_state,
    output wire [127:0] out_state
);
    function automatic [7:0] xtime(input [7:0] a);
        begin
            xtime = {a[6:0], 1'b0} ^ (8'h1b & {8{a[7]}});
        end
    endfunction

    function automatic [31:0] mix_single_column(input [31:0] c);
        reg [7:0] a0,a1,a2,a3;
        reg [7:0] r0,r1,r2,r3;
        begin
            // c packs bytes little-endian: [7:0]=b0, [15:8]=b1, ...
            a0 = c[7:0];
            a1 = c[15:8];
            a2 = c[23:16];
            a3 = c[31:24];

            // AES MixColumns matrix:
            // [2 3 1 1] [a0]
            // [1 2 3 1] [a1]
            // [1 1 2 3] [a2]
            // [3 1 1 2] [a3]
            r0 = xtime(a0) ^ (xtime(a1) ^ a1) ^ a2 ^ a3;
            r1 = a0 ^ xtime(a1) ^ (xtime(a2) ^ a2) ^ a3;
            r2 = a0 ^ a1 ^ xtime(a2) ^ (xtime(a3) ^ a3);
            r3 = (xtime(a0) ^ a0) ^ a1 ^ a2 ^ xtime(a3);

            mix_single_column = {r3, r2, r1, r0};
        end
    endfunction

    wire [31:0] c0 = in_state[31:0];
    wire [31:0] c1 = in_state[63:32];
    wire [31:0] c2 = in_state[95:64];
    wire [31:0] c3 = in_state[127:96];

    assign out_state[31:0]   = mix_single_column(c0);
    assign out_state[63:32]  = mix_single_column(c1);
    assign out_state[95:64]  = mix_single_column(c2);
    assign out_state[127:96] = mix_single_column(c3);
endmodule