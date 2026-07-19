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
  , input  alu_control_t inst // operation selector
  , output data_t out //result
);

    logic [4:0] index;
    data_t mask;

    always_comb begin
        index = reg2[4:0];
        mask = data_t'(32'h1) << index;

        case ( inst )

            // bclr / bclri  → clear selected bit
            ALU_CONTROL_BCLR: out = reg1 & ~mask;

            // bset / bseti  → set selected bit
            ALU_CONTROL_BSET: out = reg1 | mask;

            // binv / binvi  → invert selected bit
            ALU_CONTROL_BINV: out = reg1 ^ mask;

            // bext / bexti  → extract selected bit (to bit[0])
            ALU_CONTROL_BEXT: out = (reg1 >> index) & data_t'(32'h1);

            // safe default
            default: out = '0;

        endcase
    end

endmodule
