// sh1add - logical shift left by 1 and add
// sh2add - logical shift left by 2 and add
// sh3add - logical shift left by 3 and add

// Logic shift: Moves bits N positions to the left leaving 0's behind
// x << n = x * 2^n

module zba(
    input [31:0] reg1, 
    input [31:0] reg2, 
    input [1:0] inst, // two bit register, distinguish instruction
    input [2:0] funct3,  // extra function inputs
    input [6:0] funct7, 
    output reg[31:0] out
);

always @(*)
begin
    
    case (inst)

// sh1add behaviour

    2'b00: out = (reg1 << 1) + reg2;

// sh2add behaviour

    2'b01: out = (reg1 << 2) + reg2;

// sh3add

    2'b10: out = (reg1 << 3) + reg2;

// other

    default: out = 32'd0;

    endcase
end

endmodule
