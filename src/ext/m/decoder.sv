`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/m/types.svh"

/* verilator lint_off DECLFILENAME */
module ext__m__decoder
/* verilator lint_on DECLFILENAME */
    ( input [2:0] funct3
    , input [6:0] funct7
    , input opcode_t opcode
    , output logic is_mul
    , output logic is_div
`ifdef UTOSS_RISCV__MUL_ENABLED
    , output ext__m__types::m_mul_control_t mul_control
`endif
`ifdef UTOSS_RISCV__DIV_ENABLED
    , output ext__m__types::m_div_control_t div_control
`endif
    );

    always @(*) begin
        is_mul = 1'b0;
        is_div = 1'b0;
`ifdef UTOSS_RISCV__MUL_ENABLED
        mul_control = ext__m__types::M_ALU_CTRL__MUL_NONE;
`endif
`ifdef UTOSS_RISCV__DIV_ENABLED
        div_control = ext__m__types::M_ALU_CTRL__DIV_NONE;
`endif

        if (opcode == OPCODE_OP && funct7 == 7'b0000001) begin
            case (funct3)
`ifdef UTOSS_RISCV__MUL_ENABLED
            3'b000: begin is_mul = 1'b1; mul_control = ext__m__types::M_ALU_CTRL__MUL;    end
            3'b001: begin is_mul = 1'b1; mul_control = ext__m__types::M_ALU_CTRL__MULH;   end
            3'b010: begin is_mul = 1'b1; mul_control = ext__m__types::M_ALU_CTRL__MULHSU; end
            3'b011: begin is_mul = 1'b1; mul_control = ext__m__types::M_ALU_CTRL__MULHU;  end
`endif
`ifdef UTOSS_RISCV__DIV_ENABLED
            3'b100: begin is_div = 1'b1; div_control = ext__m__types::M_ALU_CTRL__DIV;  end
            3'b101: begin is_div = 1'b1; div_control = ext__m__types::M_ALU_CTRL__DIVU; end
            3'b110: begin is_div = 1'b1; div_control = ext__m__types::M_ALU_CTRL__REM;  end
            3'b111: begin is_div = 1'b1; div_control = ext__m__types::M_ALU_CTRL__REMU; end
`endif
            default:;
            endcase
        end
    end
endmodule
