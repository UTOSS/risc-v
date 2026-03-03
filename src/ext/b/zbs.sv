// Zbs: Single-Bit Operations (RV32)
// Implements the RV32 Zbs (Bit-Manipulation Single-Bit) instructions:
//   - bclr  / bclri : Clear bit
//   - bset  / bseti : Set bit
//   - binv  / binvi : Invert bit
//   - bext  / bexti : Extract bit (result placed in bit[0])
// The decoder is responsible for selecting the correct operands:
//   - For register-form instructions:
//       reg2 = rs2
//   - For immediate-form instructions:
//       reg2[4:0] = shamt
// Therefore, this module simply treats reg2[4:0] as the bit index.
//
// inst encoding (local mini-ALU selector):
//   3'b000 : bclr  / bclri
//   3'b001 : bset  / bseti
//   3'b010 : binv  / binvi
//   3'b011 : bext  / bexti
//   3'b100-111 : reserved
//
// Notes:
//   - RV32 => XLEN = 32
//   - Bit index is masked to 5 bits (0–31)
//   - All logic is purely combinational

module zbs (
    input  logic [31:0] reg1,   // rs1 operand
    input  logic [31:0] reg2,   // rs2 or immediate (index source)
    input  logic [2:0]  inst,   // operation selector
    output logic [31:0] out     // result
);

    // Extract bit index (only lower 5 bits used in RV32)
    logic [4:0]  index;

    // Bit mask for single-bit operations
    logic [31:0] mask;

    // Combinational ALU logic
    always_comb begin
    
        // reg2 may come from rs2 or immediate (handled externally)
        index = reg2[4:0];

        // Generate one-hot mask: 1 << index
        mask  = 32'h1 << index;

        // Perform selected single-bit operation
        unique case (inst)

            // Clear selected bit
            3'b000: out = reg1 & ~mask;

            // Set selected bit
            3'b001: out = reg1 |  mask;

            // Invert selected bit
            3'b010: out = reg1 ^  mask;

            // Extract selected bit into bit[0]
            // Upper bits are zero
            3'b011: out = (reg1 >> index) & 32'h1;

            // Default safe output
            default: out = 32'd0;

        endcase
    end

endmodule