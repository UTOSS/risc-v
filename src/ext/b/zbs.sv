// -----------------------------------------------------------------------------
// Zbs Extension – Single-Bit Instructions (RV32)
// Reference:
//   RISC-V Bitmanip Extension Specification v1.0.0
//   Section 5.4 – Zbs (Single-Bit Instructions)
//
// Notes:
//   - Purely combinational logic
//   - Bit index = reg2[4:0]
//   - R/I distinction handled in decode stage
// -----------------------------------------------------------------------------

module zbs (
    input  data_t reg1 // rs1 operand
  , input  data_t reg2 // rs2 or immediate (bit index source)
  , input  logic [1:0] inst // operation selector
  , output data_t out //result
);

    logic [4:0] index;
    data_t mask;

    always_comb
        index = reg2[4:0];

    always_comb
        mask = data_t'(32'h1) << index;

    always_comb
        case (inst)

            // 00 : bclr / bclri  → clear selected bit
            2'b00: out = reg1 & ~mask;

            // 01 : bset / bseti  → set selected bit
            2'b01: out = reg1 | mask;

            // 10 : binv / binvi  → invert selected bit
            2'b10: out = reg1 ^ mask;

            // 11 : bext / bexti  → extract selected bit (to bit[0])
            2'b11: out = (reg1 >> index) & data_t'(32'h1);

            // others → safe default
            default: out = '0;

        endcase

endmodule