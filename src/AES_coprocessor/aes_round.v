module aes_round (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         final_round,
    output wire [127:0] state_out
);
    // Break into bytes
    wire [7:0] b [0:15];
    genvar i;
    generate
        for (i=0; i<16; i=i+1) begin : BYTE_SPLIT
            assign b[i] = state_in[i*8 +: 8];
        end
    endgenerate

    // SubBytes
    wire [7:0] sb [0:15];
    generate
        for (i=0; i<16; i=i+1) begin : SUBBYTES
            aes_sbox u_sbox(.byte_in(b[i]), .byte_out(sb[i]));
        end
    endgenerate

    // ShiftRows (y = shifted)
    wire [7:0] sh [0:15];
    assign sh[0]  = sb[0];
    assign sh[1]  = sb[5];
    assign sh[2]  = sb[10];
    assign sh[3]  = sb[15];

    assign sh[4]  = sb[4];
    assign sh[5]  = sb[9];
    assign sh[6]  = sb[14];
    assign sh[7]  = sb[3];

    assign sh[8]  = sb[8];
    assign sh[9]  = sb[13];
    assign sh[10] = sb[2];
    assign sh[11] = sb[7];

    assign sh[12] = sb[12];
    assign sh[13] = sb[1];
    assign sh[14] = sb[6];
    assign sh[15] = sb[11];

    // Pack shifted bytes back to 128-bit
    wire [127:0] shifted_state;
    generate
        for (i=0; i<16; i=i+1) begin : PACK_SHIFT
            assign shifted_state[i*8 +: 8] = sh[i];
        end
    endgenerate

    // MixColumns
    wire [127:0] mixed_state;
    aes_mixcolumns u_mix(.in_state(shifted_state), .out_state(mixed_state));

    wire [127:0] pre_xor = final_round ? shifted_state : mixed_state;

    // AddRoundKey
    assign state_out = pre_xor ^ round_key;
endmodule