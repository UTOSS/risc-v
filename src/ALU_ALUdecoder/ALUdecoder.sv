`include "src/types.svh"

module ALUdecoder (
    input  [2:0] funct3,
    input  [6:0] funct7,
    input  alu_op_t alu_op,
    output alu_control_t alu_control
);

  //Logic
  always @(*) begin
    //Default
    alu_control = ALU_CONTROL_ADD;

    case (alu_op)

      ALU_OP__ADD: alu_control = ALU_CONTROL_ADD; //lw, sw (ADD)

      ALU_OP__BRANCH: begin
        case (funct3)
          3'b000: alu_control = ALU_CONTROL_SUB;  //beq (SUB)
          3'b001: alu_control = ALU_CONTROL_SUB;  // bne (SUB)
          3'b100: alu_control = ALU_CONTROL_SLT;  // blt (SLT)
          3'b110: alu_control = ALU_CONTROL_SLTU; // bltu (SLTU)
          3'b101: alu_control = ALU_CONTROL_SLT;  // bge (SLT)
          3'b111: alu_control = ALU_CONTROL_SLTU; // bgeu (SLTU)
          default: alu_control = ALU_CONTROL_SUB; // SUB
        endcase
      end

      ALU_OP__REGISTER_OPERATION: begin //R type
        case (funct3)
          3'b000:
            if (funct7 == 7'h00)      alu_control = ALU_CONTROL_ADD; //ADD
            else if (funct7 == 7'h20) alu_control = ALU_CONTROL_SUB; //SUB
            else                      alu_control = ALU_CONTROL_ADD; // default to ADD for invalid func7

          3'b001: alu_control = ALU_CONTROL_SLL;  //SLL
          3'b010: alu_control = ALU_CONTROL_SLT;  //SLT
          3'b011: alu_control = ALU_CONTROL_SLTU; //SLTU
          3'b100: alu_control = ALU_CONTROL_XOR;  //XOR

          3'b101:
            if (funct7 == 7'h00)      alu_control = ALU_CONTROL_SRL; //SRL
            else if (funct7 == 7'h20) alu_control = ALU_CONTROL_SRA; //SRA
            else                      alu_control = ALU_CONTROL_SRL; // default to SRL for invalid func7

          3'b110: alu_control = ALU_CONTROL_OR;  //OR
          3'b111: alu_control = ALU_CONTROL_AND; //AND
          default: alu_control = ALU_CONTROL_ADD;
        endcase
      end

      ALU_OP__UNSET: begin //I type
        case (funct3)
          3'b000: alu_control = ALU_CONTROL_ADD;  //ADDI
          3'b001: alu_control = ALU_CONTROL_SLL;  //SLLI
          3'b010: alu_control = ALU_CONTROL_SLT;  //SLTI
          3'b011: alu_control = ALU_CONTROL_SLTU; //SLTIU
          3'b100: alu_control = ALU_CONTROL_XOR;  //XORI

          3'b101:
            if (funct7 == 7'h00)      alu_control = ALU_CONTROL_SRL; //SRLI
            else if (funct7 == 7'h20) alu_control = ALU_CONTROL_SRA; //SRAI
            else                      alu_control = ALU_CONTROL_SRL; // default to SRLI for invalid func7

          // I type doesn't have funct7; the funct7 here is the upper 7 bits of the immediate
          3'b110: alu_control = ALU_CONTROL_OR;  //ORI
          3'b111: alu_control = ALU_CONTROL_AND; //ANDI
          default: alu_control = ALU_CONTROL_ADD;
        endcase
      end

      default: alu_control = ALU_CONTROL_ADD;

    endcase
  end

endmodule