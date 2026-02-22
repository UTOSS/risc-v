`include "src/types.svh"
`include "src/params.svh"
`include "src/packages/pkg_control_fsm.svh"

import pkg_control_fsm::state_t;

module Logger
( input wire clk
, input addr_t pc_cur
, input instr_t instruction
, input state_t FSM_State
, input wire [6:0] opcode
, input logic [2:0] funct3
, input logic [6:0] funct7
, input logic [4:0] rs1, rs2, rd
, input imm_t imm_ext
, input addr_t memory_address
, input data_t memory_data
, input wire write_enable
, input data_t rd1, rd2, result
, input wire regWrite
);

    /* verilator lint_off PROCASSINIT */
    integer cycle = 32'h0;
    string operation = "unknown";
    string source_register1 = "unkown";
    string source_register2 = "unknown";
    string destination_register = "unknown";
    string complete_instruction = "unknown";
    /* verilator lint_on PROCASSINIT */

    data_t new_pc;

    assign new_pc = pc_cur + imm_ext + 'h4;

    always_ff @(posedge clk) begin //stricter by enforcing purely sequential block
        // Display the high-level PC and instruction information
        $display("Cycle %d: \nPC: %08h \nInstruction (Hex): %08h", cycle, pc_cur, instruction);

        // Display the FSM State we are in
        $display("FSM State: %s", FSM_State.name());

        // Parse the instruction we are executing
        case (opcode)
        RType: begin
            case (funct3)
            3'b000: begin
                case (funct7)
                    7'h00: operation <= "add";
                    7'h20: operation <= "sub";
                    default: ;
                endcase
            end
            3'b001: operation <= "sll";
            3'b010: operation <= "slt";
            3'b011: operation <= "sltu";
            3'b100: operation <= "xor";
            3'b101: begin
                case (funct7)
                    7'h00: operation <= "srl";
                    7'h20: operation <= "sra";
                    default: ;
                endcase
            end
            3'b110: operation <= "or";
            3'b111: operation <= "and";
            endcase
        end

        IType_logic: begin
            case (funct3)
            3'b000: operation <= "addi";
            3'b001: operation <= "slli";
            3'b010: operation <= "slti";
            3'b011: operation <= "sltiu";
            3'b100: operation <= "xori";
            3'b101: begin
                case (funct7)
                    7'h00: operation <= "srli";
                    7'h20: operation <= "srai";
                    default: ;
                endcase
            end
            3'b110: operation <= "ori";
            3'b111: operation <= "andi";
            default: ;
            endcase
        end

        IType_load: begin
            case (funct3)
            3'b000: operation <= "lb";
            3'b001: operation <= "lh";
            3'b010: operation <= "lw";
            3'b100: operation <= "lbu";
            3'b101: operation <= "lhu";
            default: ;
            endcase
        end

        SType: begin
            case (funct3)
            3'b000: operation <= "sb";
            3'b001: operation <= "sh";
            3'b010: operation <= "sw";
            default: ;
            endcase
        end

        BType: begin
            case (funct3)
            3'b000: operation <= "beq";
            3'b001: operation <= "bne";
            3'b100: operation <= "blt";
            3'b101: operation <= "bge";
            3'b110: operation <= "bltu";
            3'b111: operation <= "bgeu";
            default: ;
            endcase
        end

        JType:         operation <= "jal";
        UType_auipc:   operation <= "auipc";
        UType_lui:     operation <= "lui";
        IType_jalr:    operation <= "jalr";
        default:       operation <= "unknown";
        endcase

        // Parse register names
        case (rs1)
        5'b00000: source_register1 <= "zero";
        5'b00001: source_register1 <= "ra";
        5'b00010: source_register1 <= "sp";
        5'b00011: source_register1 <= "gp";
        5'b00100: source_register1 <= "tp";
        5'b00101: source_register1 <= "t0";
        5'b00110: source_register1 <= "t1";
        5'b00111: source_register1 <= "t2";
        5'b01000: source_register1 <= "s0";
        5'b01001: source_register1 <= "s1";
        5'b01010: source_register1 <= "a0";
        5'b01011: source_register1 <= "a1";
        5'b01100: source_register1 <= "a2";
        5'b01101: source_register1 <= "a3";
        5'b01110: source_register1 <= "a4";
        5'b01111: source_register1 <= "a5";
        5'b10000: source_register1 <= "a6";
        5'b10001: source_register1 <= "a7";
        5'b10010: source_register1 <= "s2";
        5'b10011: source_register1 <= "s3";
        5'b10100: source_register1 <= "s4";
        5'b10101: source_register1 <= "s5";
        5'b10110: source_register1 <= "s6";
        5'b10111: source_register1 <= "s7";
        5'b11000: source_register1 <= "s8";
        5'b11001: source_register1 <= "s9";
        5'b11010: source_register1 <= "s10";
        5'b11011: source_register1 <= "s11";
        5'b11100: source_register1 <= "t3";
        5'b11101: source_register1 <= "t4";
        5'b11110: source_register1 <= "t5";
        5'b11111: source_register1 <= "t6";
        endcase

        case (rs2)
        5'b00000: source_register2 <= "zero";
        5'b00001: source_register2 <= "ra";
        5'b00010: source_register2 <= "sp";
        5'b00011: source_register2 <= "gp";
        5'b00100: source_register2 <= "tp";
        5'b00101: source_register2 <= "t0";
        5'b00110: source_register2 <= "t1";
        5'b00111: source_register2 <= "t2";
        5'b01000: source_register2 <= "s0";
        5'b01001: source_register2 <= "s1";
        5'b01010: source_register2 <= "a0";
        5'b01011: source_register2 <= "a1";
        5'b01100: source_register2 <= "a2";
        5'b01101: source_register2 <= "a3";
        5'b01110: source_register2 <= "a4";
        5'b01111: source_register2 <= "a5";
        5'b10000: source_register2 <= "a6";
        5'b10001: source_register2 <= "a7";
        5'b10010: source_register2 <= "s2";
        5'b10011: source_register2 <= "s3";
        5'b10100: source_register2 <= "s4";
        5'b10101: source_register2 <= "s5";
        5'b10110: source_register2 <= "s6";
        5'b10111: source_register2 <= "s7";
        5'b11000: source_register2 <= "s8";
        5'b11001: source_register2 <= "s9";
        5'b11010: source_register2 <= "s10";
        5'b11011: source_register2 <= "s11";
        5'b11100: source_register2 <= "t3";
        5'b11101: source_register2 <= "t4";
        5'b11110: source_register2 <= "t5";
        5'b11111: source_register2 <= "t6";
        endcase

        case (rd)
        5'b00000: destination_register <= "zero";
        5'b00001: destination_register <= "ra";
        5'b00010: destination_register <= "sp";
        5'b00011: destination_register <= "gp";
        5'b00100: destination_register <= "tp";
        5'b00101: destination_register <= "t0";
        5'b00110: destination_register <= "t1";
        5'b00111: destination_register <= "t2";
        5'b01000: destination_register <= "s0";
        5'b01001: destination_register <= "s1";
        5'b01010: destination_register <= "a0";
        5'b01011: destination_register <= "a1";
        5'b01100: destination_register <= "a2";
        5'b01101: destination_register <= "a3";
        5'b01110: destination_register <= "a4";
        5'b01111: destination_register <= "a5";
        5'b10000: destination_register <= "a6";
        5'b10001: destination_register <= "a7";
        5'b10010: destination_register <= "s2";
        5'b10011: destination_register <= "s3";
        5'b10100: destination_register <= "s4";
        5'b10101: destination_register <= "s5";
        5'b10110: destination_register <= "s6";
        5'b10111: destination_register <= "s7";
        5'b11000: destination_register <= "s8";
        5'b11001: destination_register <= "s9";
        5'b11010: destination_register <= "s10";
        5'b11011: destination_register <= "s11";
        5'b11100: destination_register <= "t3";
        5'b11101: destination_register <= "t4";
        5'b11110: destination_register <= "t5";
        5'b11111: destination_register <= "t6";
        endcase

        // Construct the instruction to display
        case (opcode)
        RType:         complete_instruction <= {operation, " ", destination_register, ", ", source_register1, ", ", source_register2};
        IType_logic:   complete_instruction <= {operation, " ", destination_register, ", ", source_register1, ", 0x", $sformatf("%08h", imm_ext)};
        IType_load:    complete_instruction <= {operation, " ", destination_register, ", ", $sformatf("%0d", imm_ext), "(", source_register1, ")"};
        SType:         complete_instruction <= {operation, " ", source_register2, ", ", $sformatf("%0d", imm_ext), "(", source_register1, ")"};
        BType:         complete_instruction <= {operation, " ", source_register1, ", ", source_register2, ", 0x", $sformatf("%08h", new_pc)};
        JType:         complete_instruction <= {operation, " ", destination_register, ", 0x", $sformatf("%08h", new_pc)};
        UType_auipc:   complete_instruction <= {operation, " ", destination_register, ", 0x", $sformatf("%08h", imm_ext)};
        UType_lui:     complete_instruction <= {operation, " ", destination_register, ", 0x", $sformatf("%08h", imm_ext)};
        IType_jalr:    complete_instruction <= {operation, " ", destination_register, ", ", source_register1, ", 0x", $sformatf("%08h", new_pc)};
        default:       complete_instruction <= "unknown";
        endcase

        // Display the parsed instruction
        $display("Parsed Instruction: %s", complete_instruction);

        // Display the value read from memory
        $display("Read Memory Address: 0x%08h", memory_address, " Value: 0x%08h", memory_data);

        // If data is being written, display what and where
        if (write_enable) begin
        $display("Write Memory Address: 0x%08h", memory_address, " Value: 0x%08h", memory_data);
        end

        // Display values read from register file
        if (rs1 != 5'b00000) begin
        $display("Read Register: %s", source_register1, " Value: 0x%08h", rd1);
        end

        if (rs2 != 5'b00000) begin
        $display("Read Register: %s", source_register2, " Value: 0x%08h", rd2);
        end

        // If data is being written to register, display what and where
        if (regWrite && rd != 5'b00000) begin
        $display("Write Register: %s", destination_register, " Value: 0x%08h", result);
        end

        // Include new line to separate log into packets
        $display("\n");

        cycle <= cycle + 1'b1;
    end

endmodule
