module aes_key_schedule(
    input  wire [127:0] key_in,
    input  wire [3:0]   round,  
    output wire [127:0] key_out
);
    wire [31:0] W0 = key_in[31:0];
    wire [31:0] W1 = key_in[63:32];
    wire [31:0] W2 = key_in[95:64];
    wire [31:0] W3 = key_in[127:96];

    // RotWord: rotate left by 1 byte: [b3 b2 b1 b0] as bytes -> [b2 b1 b0 b3]
    wire [31:0] rot = {W3[23:0], W3[31:24]};

    // SubWord: apply S-box to each byte of rot
    wire [7:0] sw0, sw1, sw2, sw3;
    aes_sbox s0(.byte_in(rot[7:0]),   .byte_out(sw0));
    aes_sbox s1(.byte_in(rot[15:8]),  .byte_out(sw1));
    aes_sbox s2(.byte_in(rot[23:16]), .byte_out(sw2));
    aes_sbox s3(.byte_in(rot[31:24]), .byte_out(sw3));
    wire [31:0] sub = {sw3, sw2, sw1, sw0};

    // Rcon lookup (AES-128 uses 10 values)
    reg [7:0] rcon;
    always @(*) begin
        case (round)
            4'd1:  rcon = 8'h01;
            4'd2:  rcon = 8'h02;
            4'd3:  rcon = 8'h04;
            4'd4:  rcon = 8'h08;
            4'd5:  rcon = 8'h10;
            4'd6:  rcon = 8'h20;
            4'd7:  rcon = 8'h40;
            4'd8:  rcon = 8'h80;
            4'd9:  rcon = 8'h1B;
            4'd10: rcon = 8'h36;
            default: rcon = 8'h00;
        endcase
    end

    wire [31:0] temp = sub ^ {24'h0, rcon};

    wire [31:0] W0n = W0 ^ temp;
    wire [31:0] W1n = W1 ^ W0n;
    wire [31:0] W2n = W2 ^ W1n;
    wire [31:0] W3n = W3 ^ W2n;

    assign key_out = {W3n, W2n, W1n, W0n};
endmodule