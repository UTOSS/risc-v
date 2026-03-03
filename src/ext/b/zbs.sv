// Zbs: Single-Bit Operations (RV32)
//
// Implements:
//  - bclr / bclri
//  - bset / bseti
//  - binv / binvi
//  - bext / bexti
//
// Design note:
//  - This module is purely functional.
//  - reg2[4:0] is treated as the bit index.
//  - R/I distinction is handled in the decoder.

module zbs (
    input  logic [31:0] reg1 , // rs1 operand
    input  logic [31:0] reg2 , // rs2 or immediate (bit index source)
    input  logic [1:0]  inst , // operation selector
    output logic [31:0] out    // result
);

    logic [4:0] index ;
    logic [31:0] mask ;

    always_comb
        begin
            index = reg2[4:0];
            mask  = 32'h1 << index;

            // Zbs operation selector
            case (inst)

                // 000 : bclr / bclri  → clear selected bit
                3'b000 : out = reg1 & ~mask;

                // 001 : bset / bseti  → set selected bit
                3'b001 : out = reg1 | mask;

                // 010 : binv / binvi  → invert selected bit
                3'b010 : out = reg1 ^ mask;

                // 011 : bext / bexti  → extract selected bit (to bit[0])
                3'b011 : out = (reg1 >> index) & 32'h1;

                // others → safe default
                default : out = 32'd0;

            endcase
        end

endmodule