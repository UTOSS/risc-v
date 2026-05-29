`include "src/headers/types.svh"
`include "src/headers/params.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/id_to_ex_if.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/ex_to_if_if.svh"
`include "src/interfaces/mem_to_wb_if.svh"
`include "src/timescale.svh"

module Logger
( input wire clk
, input wire reset

, input if_to_id_t  if_stage
, input if_to_id_t  id_stage
, input id_to_ex_t  ex_stage
, input ex_to_mem_t ex_stage_out
, input ex_to_if_t  ex_to_if
, input ex_to_mem_t mem_stage
, input mem_to_wb_t mem_stage_out
, input mem_to_wb_t wb_stage

, input addr_t      imem_address
, input addr_t      dmem_address
, input data_t      dmem_read_data
, input data_t      dmem_write_data
, input logic [3:0] dmem_write_enable

, input data_t      wb_result
, input logic [4:0] wb_rd

, input logic stall_f
, input logic stall_d
, input logic flush_f
, input logic flush_d
, input logic flush_e
);

    /* verilator lint_off PROCASSINIT */
    integer cycle = 32'h0;
    /* verilator lint_on PROCASSINIT */

    function automatic string reg_name(input logic [4:0] reg_idx);
        case (reg_idx)
            5'd0:  reg_name = "zero";
            5'd1:  reg_name = "ra";
            5'd2:  reg_name = "sp";
            5'd3:  reg_name = "gp";
            5'd4:  reg_name = "tp";
            5'd5:  reg_name = "t0";
            5'd6:  reg_name = "t1";
            5'd7:  reg_name = "t2";
            5'd8:  reg_name = "s0";
            5'd9:  reg_name = "s1";
            5'd10: reg_name = "a0";
            5'd11: reg_name = "a1";
            5'd12: reg_name = "a2";
            5'd13: reg_name = "a3";
            5'd14: reg_name = "a4";
            5'd15: reg_name = "a5";
            5'd16: reg_name = "a6";
            5'd17: reg_name = "a7";
            5'd18: reg_name = "s2";
            5'd19: reg_name = "s3";
            5'd20: reg_name = "s4";
            5'd21: reg_name = "s5";
            5'd22: reg_name = "s6";
            5'd23: reg_name = "s7";
            5'd24: reg_name = "s8";
            5'd25: reg_name = "s9";
            5'd26: reg_name = "s10";
            5'd27: reg_name = "s11";
            5'd28: reg_name = "t3";
            5'd29: reg_name = "t4";
            5'd30: reg_name = "t5";
            5'd31: reg_name = "t6";
            default: reg_name = "x?";
        endcase
    endfunction

        function automatic string op_name
            ( input logic [6:0] opcode
            , input logic [2:0] funct3
            , input logic [6:0] funct7
            );
        op_name = "unknown";

        case (opcode)
            RType:
                case (funct3)
                    3'b000: op_name = (funct7 == 7'h20) ? "sub" : "add";
                    3'b001: op_name = "sll";
                    3'b010: op_name = "slt";
                    3'b011: op_name = "sltu";
                    3'b100: op_name = "xor";
                    3'b101: op_name = (funct7 == 7'h20) ? "sra" : "srl";
                    3'b110: op_name = "or";
                    3'b111: op_name = "and";
                    default:;
                endcase

            IType_logic:
                case (funct3)
                    3'b000: op_name = "addi";
                    3'b001: op_name = "slli";
                    3'b010: op_name = "slti";
                    3'b011: op_name = "sltiu";
                    3'b100: op_name = "xori";
                    3'b101: op_name = (funct7 == 7'h20) ? "srai" : "srli";
                    3'b110: op_name = "ori";
                    3'b111: op_name = "andi";
                    default:;
                endcase

            IType_load:
                case (funct3)
                    3'b000: op_name = "lb";
                    3'b001: op_name = "lh";
                    3'b010: op_name = "lw";
                    3'b100: op_name = "lbu";
                    3'b101: op_name = "lhu";
                    default:;
                endcase

            SType:
                case (funct3)
                    3'b000: op_name = "sb";
                    3'b001: op_name = "sh";
                    3'b010: op_name = "sw";
                    default:;
                endcase

            BType:
                case (funct3)
                    3'b000: op_name = "beq";
                    3'b001: op_name = "bne";
                    3'b100: op_name = "blt";
                    3'b101: op_name = "bge";
                    3'b110: op_name = "bltu";
                    3'b111: op_name = "bgeu";
                    default:;
                endcase

            JType:       op_name = "jal";
            UType_auipc: op_name = "auipc";
            UType_lui:   op_name = "lui";
            IType_jalr:  op_name = "jalr";
            FENCE:       op_name = "fence";
`ifdef UTOSS_RISCV__ZICSR_ENABLED
            SYSTEM:
                case (funct3)
                    3'b001: op_name = "csrrw";
                    3'b010: op_name = "csrrs";
                    3'b011: op_name = "csrrc";
                    3'b101: op_name = "csrrwi";
                    3'b110: op_name = "csrrsi";
                    3'b111: op_name = "csrrci";
                    default:;
                endcase
`endif
            default:;
        endcase
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            cycle <= 32'h0;
        end else begin
            logic [4:0] if_rs1;
            logic [4:0] if_rs2;
            logic [4:0] if_rd;
            logic [4:0] id_rs1;
            logic [4:0] id_rs2;
            logic [4:0] id_rd;

            if_rs1 = if_stage.instruction[19:15];
            if_rs2 = if_stage.instruction[24:20];
            if_rd  = if_stage.instruction[11:7];
            id_rs1 = id_stage.instruction[19:15];
            id_rs2 = id_stage.instruction[24:20];
            id_rd  = id_stage.instruction[11:7];

                        $display("================ Pipeline Cycle %0d ================", cycle);
                        $display
                            ( "Hazard ctrl: stall_f=%0b stall_d=%0b flush_f=%0b flush_d=%0b flush_e=%0b"
                            , stall_f
                            , stall_d
                            , flush_f
                            , flush_d
                            , flush_e
                            );

                        $display
                            ( "IF : pc=%08h instr=%08h op=%s rs1=%s rs2=%s rd=%s imem_addr=%08h"
                            , if_stage.pc_cur
                            , if_stage.instruction
                                                        , op_name
                                                            ( if_stage.instruction[6:0]
                                                            , if_stage.instruction[14:12]
                                                            , if_stage.instruction[31:25]
                                                            )
                            , reg_name(if_rs1)
                            , reg_name(if_rs2)
                            , reg_name(if_rd)
                            , imem_address
                            );

                        $display
                            ( "ID : pc=%08h instr=%08h op=%s rs1=%s rs2=%s rd=%s imm=%08h"
                            , id_stage.pc_cur
                            , id_stage.instruction
                                                        , op_name
                                                            ( id_stage.instruction[6:0]
                                                            , id_stage.instruction[14:12]
                                                            , id_stage.instruction[31:25]
                                                            )
                            , reg_name(id_rs1)
                            , reg_name(id_rs2)
                            , reg_name(id_rd)
                            , ex_stage.imm_ext
                            );

                        $display
                            ( "EX : pc=%08h rd1=%08h rd2=%08h alu_ctl=%0d alu_result=%08h branch=%0b jump=%0b pc_src=%0b pc_target=%08h rd=%s regwrite=%0b memwrite=%0b"
                            , ex_stage.pc_cur
                            , ex_stage.rd1
                            , ex_stage.rd2
                            , ex_stage.alu_control
                            , ex_stage_out.alu_result
                            , ex_stage.branch
                            , ex_stage.jump
                            , ex_to_if.pc_src
                            , ex_to_if.pc_target
                            , reg_name(ex_stage_out.rd)
                            , ex_stage_out.reg_write
                            , ex_stage_out.mem_write
                            );

                        $display
                            ( "MEM: addr=%08h we=%b wdata=%08h rdata=%08h alu_result=%08h rd=%s result_src=%0d regwrite=%0b"
                            , dmem_address
                            , dmem_write_enable
                            , dmem_write_data
                            , dmem_read_data
                            , mem_stage.alu_result
                            , reg_name(mem_stage.rd)
                            , mem_stage.result_src
                            , mem_stage.reg_write
                            );

                        $display
                            ( "WB : rd=%s(%0d) regwrite=%0b result_src=%0d wb_result=%08h alu_result=%08h"
                            , reg_name(wb_rd)
                            , wb_rd
                            , wb_stage.reg_write
                            , wb_stage.result_src
                            , wb_result
                            , wb_stage.alu_result
                            );

            $display("=====================================================\n");
            cycle <= cycle + 1'b1;
        end
    end

        wire unused = &{
                1'b0
            , ex_stage
            , ex_stage_out
            , mem_stage
            , if_stage.pc_plus_4
            , id_stage.pc_plus_4
            , ex_stage.alu_src_a
            , ex_stage.alu_src_b
            , ex_stage.result_src
            , ex_stage.pc_plus_4
            , ex_stage.pc_target_kind
            , ex_stage.rs1
            , ex_stage.rs2
            , ex_to_if.pc_old
            , ex_to_if.imm_ext
            , mem_stage.write_data_e
            , mem_stage.funct3
            , mem_stage.pc_cur
            , mem_stage.pc_plus_4
            , mem_stage_out.reg_write
            , mem_stage_out.result_src
            , mem_stage_out.alu_result
            , mem_stage_out.rd
            , mem_stage_out.pc_cur
            , mem_stage_out.pc_plus_4
            , mem_stage_out.funct3
            , wb_stage.rd
            , wb_stage.pc_cur
            , wb_stage.pc_plus_4
            , wb_stage.funct3
            , dmem_write_enable
        };

endmodule
