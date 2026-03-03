// Zbs: Single-Bit Operations (RV32)
//
// Implements:
//  - bclr / bclri
//  - bset / bseti
//  - binv / binvi
//  - bext / bexti
//
// Design note:
//  - Purely combinational ALU block
//  - reg2[4:0] used as bit index
//  - R/I distinction handled in decoder

module zbs (
    input logic [31:0] reg1 // rs1 operand
    , input logic [31:0] reg2 // rs2 or immediate (bit index source)
    , input logic [1:0] inst // operation selector
    , output logic [31:0] out //result
);

    logic [4:0] index;
    logic [31:0] mask;

    always_comb
        index = reg2[4:0];

    always_comb
        mask = 32'h1 << index;

    always_comb
        case (inst)

            // 00 : bclr / bclri  → clear selected bit
            2'b00: out = reg1 & ~mask;

            // 01 : bset / bseti  → set selected bit
            2'b01: out = reg1 | mask;

            // 10 : binv / binvi  → invert selected bit
            2'b10: out = reg1 ^ mask;

            // 11 : bext / bexti  → extract selected bit (to bit[0])
            2'b11: out = (reg1 >> index) & 32'h1;

            // others → safe default
            default: out = 32'd0;

        endcase

endmodule