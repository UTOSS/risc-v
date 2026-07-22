`include "src/ext/b/types.svh"

module ext__b__decoder
  ( input [2:0] funct3
  , input [6:0] funct7
  , input [6:0] opcode
  , input [4:0] rd
  , output ext__b__types::b_alu_control_t b_alu_control
  );

  import ext__b__types::*;

  localparam bit [6:0] FUNCT7_ZBA = 7'b0010000;
  localparam bit [6:0] FUNCT7_ZBB = 7'b0100000;
  localparam bit [6:0] FUNCT7_ZBS_BSET = 7'b0010100;
  localparam bit [6:0] FUNCT7_ZBS_BCLR = 7'b0100100;
  localparam bit [6:0] FUNCT7_ZBS_BINV = 7'b0110100;

  always_comb begin
    b_alu_control = B_ALU_CTRL__NONE;

    case (opcode)
      7'b0110011:
        case (funct7)
          FUNCT7_ZBA:
            case (funct3)
              3'b010:  b_alu_control = B_ALU_CTRL__SH1ADD;
              3'b100:  b_alu_control = B_ALU_CTRL__SH2ADD;
              3'b110:  b_alu_control = B_ALU_CTRL__SH3ADD;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase

          FUNCT7_ZBB:
            case (funct3)
              3'b111:  b_alu_control = B_ALU_CTRL__ANDN;
              3'b110:  b_alu_control = B_ALU_CTRL__ORN;
              3'b100:  b_alu_control = B_ALU_CTRL__XNOR;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase

          FUNCT7_ZBS_BSET:
            if (funct3 == 3'b001) begin
              b_alu_control = B_ALU_CTRL__BSET;
            end

          FUNCT7_ZBS_BCLR:
            case (funct3)
              3'b001: b_alu_control = B_ALU_CTRL__BCLR;
              3'b101: b_alu_control = B_ALU_CTRL__BEXT;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase

          FUNCT7_ZBS_BINV:
            if (funct3 == 3'b001) begin
              b_alu_control = B_ALU_CTRL__BINV;
            end

          default: b_alu_control = B_ALU_CTRL__NONE;

        endcase

      7'b0010011:
        case (funct7)
          FUNCT7_ZBS_BSET:
            if (funct3 == 3'b001) begin
              b_alu_control = B_ALU_CTRL__BSET;
            end

          FUNCT7_ZBS_BCLR:
            case (funct3)
              3'b001: b_alu_control = B_ALU_CTRL__BCLR;
              3'b101: b_alu_control = B_ALU_CTRL__BEXT;
              default: b_alu_control = B_ALU_CTRL__NONE;
            endcase

          FUNCT7_ZBS_BINV:
            if (funct3 == 3'b001) begin
              b_alu_control = B_ALU_CTRL__BINV;
            end

          default: b_alu_control = B_ALU_CTRL__NONE;
        endcase

      default: b_alu_control = B_ALU_CTRL__NONE;
    endcase
  end

endmodule
