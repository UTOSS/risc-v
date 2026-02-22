//created by Joonseo Park, for University of Toronto Open Source Society
//A Moore Type Finite State Machine for the RV32I Microprocessor Control Unit

`include "src/types.svh"
`include "src/params.svh"
`include "src/packages/pkg_control_fsm.svh"
`timescale 1ns/1ps


/* verilator lint_off IMPORTSTAR */
import pkg_control_fsm::*;
/* lint_on IMPORTSTAR */

module ControlFSM
  ( input opcode_t opcode
  , input wire clk
  , input wire reset
  , input wire zero_flag
  , input wire [3:0] MemWriteByteAddress
  , input wire [2:0] funct3
  , input data_t alu_result
  , output adr_src_t AdrSrc
  , output reg IRWrite
  , output reg RegWrite
  , output reg PCUpdate
  , output pc_src_t pc_src
  , output reg [3:0] MemWrite
  , output reg Branch
  , output alu_src_a_t ALUSrcA
  , output alu_src_b_t ALUSrcB
  , output result_src_t ResultSrc
  , output state_t FSMState
  );

  //declare state registers
  state_t current_state, next_state;

  //Next state logic
  always @(*)begin

    case (current_state)

      FETCH:      next_state = FETCH_WAIT;
      FETCH_WAIT: next_state = DECODE;

      DECODE: begin

        if (opcode == JType) next_state = UNCONDJUMP;

        else if (opcode == RType) next_state = EXECUTER;

        else if (opcode == IType_logic) next_state = EXECUTEI;

        else if (opcode == IType_load || opcode == SType) next_state = MEMADR;

        else if (opcode == BType) begin

          case (funct3)

            3'b000: next_state = BRANCHIFEQ;

            3'b001: next_state = BRANCHIFEQ;

            default: next_state = BRANCHCOMP;

          endcase

        end

        else if (opcode == UType_auipc) next_state = AUIPC;

        else if (opcode == UType_lui) next_state = LUI;

        else if (opcode == IType_jalr) next_state = JALR_CALC;

        else if (opcode == FENCE)     next_state = FETCH;

        else next_state = DECODE;

      end

      AUIPC: next_state = ALUWB;

      LUI: next_state = ALUWB;

      UNCONDJUMP: next_state = ALUWB;

      EXECUTER: next_state = ALUWB;

      EXECUTEI: next_state = ALUWB;

      MEMADR: begin

        if (opcode == IType_load) next_state = MEMREAD;

        else if (opcode == SType) next_state = MEMWRITE;

        else next_state = MEMADR;

      end

      BRANCHIFEQ: next_state = FETCH;

      BRANCHCOMP: next_state = FETCH;

      ALUWB: next_state = FETCH;

      MEMREAD: next_state = MEMWB;

      MEMWRITE: next_state = FETCH;

      MEMWB: next_state = FETCH;

      JALR_CALC:  next_state = JALR_STEP2;

      JALR_STEP2: next_state = ALUWB;

      default: next_state = FETCH;

    endcase

  end

  //output logic

  /* verilator lint_off LATCH */
  always @(*) begin
    Branch = 1'b0;
    pc_src = PC_SRC__INCREMENT;
    PCUpdate = 1'b0;
    IRWrite = 1'b0;
    MemWrite = 4'b0;
    RegWrite = 1'b0;
    AdrSrc    = ADR_SRC__PC;
    ResultSrc = RESULT_SRC__ALU_OUT;
    FSMState = current_state;

    case (current_state)

      FETCH: begin
        AdrSrc   = ADR_SRC__PC;
      end

      FETCH_WAIT: begin
        AdrSrc   = ADR_SRC__PC;
        IRWrite  = 1'b1;
        PCUpdate = 1'b1;
        pc_src   = PC_SRC__INCREMENT;
      end


      DECODE: begin

        ALUSrcA = ALU_SRC_A__OLD_PC;
        ALUSrcB = ALU_SRC_B__IMM_EXT;

      end

      AUIPC: begin

        ALUSrcA = ALU_SRC_A__OLD_PC;
        ALUSrcB = ALU_SRC_B__IMM_EXT;

      end

      LUI: begin

        ALUSrcA = ALU_SRC_A__ZERO;
        ALUSrcB = ALU_SRC_B__IMM_EXT;

      end

      EXECUTER: begin

        ALUSrcA = ALU_SRC_A__RD1;
        ALUSrcB = ALU_SRC_B__RD2;

      end

      EXECUTEI: begin

        ALUSrcA = ALU_SRC_A__RD1;
        ALUSrcB = ALU_SRC_B__IMM_EXT;

      end

      UNCONDJUMP: begin

        ALUSrcA = ALU_SRC_A__OLD_PC;
        ALUSrcB = ALU_SRC_B__4;
        ResultSrc = RESULT_SRC__ALU_OUT;
        PCUpdate = 1'b1;
        pc_src    = PC_SRC__JUMP;  // new added

      end

      JALR_CALC: begin
        ALUSrcA  = ALU_SRC_A__RD1;      // rs1
        ALUSrcB  = ALU_SRC_B__IMM_EXT;  // + imm
      end

      JALR_STEP2: begin
        ALUSrcA   = ALU_SRC_A__OLD_PC;  // Calculate link = pc_old + 4, write back in ALUWB
        ALUSrcB   = ALU_SRC_B__4;
        ResultSrc = RESULT_SRC__ALU_OUT;
        pc_src    = PC_SRC__ALU_RESULT; // fetch  (alu_out & ~1) for new PC
        PCUpdate  = 1'b1;
      end


      MEMADR: begin

        ALUSrcA = ALU_SRC_A__RD1;
        ALUSrcB = ALU_SRC_B__IMM_EXT;
        AdrSrc    = ADR_SRC__RESULT;
        ResultSrc = RESULT_SRC__ALU_RESULT;

      end

      BRANCHIFEQ: begin

        ALUSrcA = ALU_SRC_A__RD1;
        ALUSrcB = ALU_SRC_B__RD2;
        ResultSrc = RESULT_SRC__ALU_OUT;
        Branch = 1'b1;
        case (funct3)
          3'b000: begin
            if (zero_flag) begin
              pc_src = PC_SRC__JUMP;
              PCUpdate = 1'b1;
            end
            else pc_src = PC_SRC__INCREMENT;
          end

          3'b001: begin
            if (!zero_flag) begin
              pc_src = PC_SRC__JUMP;
              PCUpdate = 1'b1;
            end
            else pc_src = PC_SRC__INCREMENT;
          end
          default: ;
        endcase
      end

      BRANCHCOMP: begin

        ALUSrcA = ALU_SRC_A__RD1;
        ALUSrcB = ALU_SRC_B__RD2;
        ResultSrc = RESULT_SRC__ALU_OUT;
        Branch = 1'b1;
        if (alu_result == 32'b1) begin
          pc_src = PC_SRC__JUMP;
          PCUpdate = 1'b1;
        end
        else pc_src = PC_SRC__INCREMENT;

      end

      ALUWB: begin

        ResultSrc = RESULT_SRC__ALU_OUT;
        RegWrite = 1'b1;

      end

      MEMWRITE: begin

        ResultSrc = RESULT_SRC__ALU_OUT;
        AdrSrc = ADR_SRC__RESULT;
        MemWrite = MemWriteByteAddress;

      end

      MEMREAD: begin

        ResultSrc = RESULT_SRC__ALU_OUT;
        AdrSrc = ADR_SRC__RESULT;

      end

      MEMWB: begin

        ResultSrc = RESULT_SRC__DATA;
        RegWrite = 1'b1;

      end

      default: begin //by default, we return to FETCH state

        AdrSrc = ADR_SRC__PC;
        IRWrite = 1'b1;

      end


    endcase

  end
  /* verilator lint_off LATCH */

  //State transition logic (sequential)
  always @ (posedge clk) begin

    if (reset) current_state <= FETCH;

    else begin
      current_state <= next_state;
    end

  end
endmodule
