`include "src/types.svh"

module ALUdecoder ( input [2:0] funct3,
                    input [6:0] funct7,
                    input alu_op_t alu_op,
                    output alu_op_t_low alu_control
                  );
  //Internal Reg
    reg alu_op_t_low alu_control_r;
    assign alu_control = alu_control_r;

  //Logic
  always @(*)
  begin
    //Default
    alu_control_r = ALUAdd;
  case (alu_op)
    ALU_OP__ADD: alu_control_r = ALUAdd; //lw, sw (ADD)
    ALU_OP__BRANCH:
    begin
      case (funct3)
      3'b000: alu_control_r = ALUSub; //beq (SUB)
      3'b001: alu_control_r = ALUSub; // bne (SUB)
      3'b100: alu_control_r = ALUSLT; // blt (SLT)
      3'b110: alu_control_r = ALUSLTU; // bltu (SLTU)
      3'b101: alu_control_r = ALUSLT; // bge (SLT)
      3'b111: alu_control_r = ALUSLTU; // bgeu (SLTU)
      default: alu_control_r = ALUSub; // SUB
      endcase
    end
    ALU_OP__REGISTER_OPERATION: //R type
    begin
      case (funct3)
      3'b000: if (funct7 == 7'h00) alu_control_r = ALUAdd;      //ADD
        else if (funct7 == 7'h20) alu_control_r = ALUSub; //SUB
        else alu_control_r = ALUAdd; // default to ADD for invalid func7
      3'b001: alu_control_r = ALUSLL;                         //SLL
      3'b010: alu_control_r = ALUSLT;                         //SLT
      3'b011: alu_control_r = ALUSLTU;                         //SLTU
      3'b100: alu_control_r = ALUXOR;              //XOR
      3'b101: if (funct7 == 7'h00) alu_control_r = ALUSRL;      //SRL
        else if (funct7 == 7'h20) alu_control_r = ALUSRA; //SRA
        else alu_control_r = ALUSRL; // default to SRL for invalid func7
      3'b110: alu_control_r = ALUOR;                         //OR
      3'b111: alu_control_r = ALUAND;                         //AND
      default: alu_control_r = ALUAdd;
      endcase
    end
    ALU_OP__UNSET: //I type
    begin
      case (funct3)
      3'b000: alu_control_r = ALUAdd;                //ADDI
      3'b001: alu_control_r = ALUSLL;                         //SLLI
      3'b010: alu_control_r = ALUSLT;                         //SLTI
      3'b011: alu_control_r = ALUSLTU;                         //SLTIU
      3'b100: alu_control_r = ALUXOR;              //XORI
      3'b101: if (funct7 == 7'h00) alu_control_r = ALUSRL;      //SRLI
        else if (funct7 == 7'h20) alu_control_r = ALUSRA;    //SRAI
        else alu_control_r = ALUSRL; // default to SRLI for invalid func7
// I type doesn't have funct7; the funct7 here is the upper 7 bits of the immediate
      3'b110: alu_control_r = ALUOR;                         //ORI
      3'b111: alu_control_r = ALUAND;                         //ANDI
      default: alu_control_r = ALUAdd;
      endcase
    end
    default: alu_control_r = ALUAdd;
  endcase
  end
endmodule
