
// TODO: review all the signal assignments
module control_fsm_pipelined
  ( input var logic clk
  , input var logic reset

  , input opcode_t opcode
  , input var logic [2:0] func3

  , output var logic               reg_write
  , output write_back_result_src_t result_src
  , output var logic               mem_write
  , output var logic               jump
  , output var logic               branch
  , output var logic               alu_src
  );

  always_comb
    reg_write = opcode inside {JType, RType, IType_logic, IType_jalr, UType_auipc, UType_lui};

  always_comb
    case (opcode)
      RType, IType_logic:
        result_src = WRITE_BACK_RESULT_SRC__ALU_RESULT;
      IType_Load:
        result_src = WRITE_BACK_RESULT_SRC__READ_DATA;
      IType_jalr:
        result_src = WRITE_BACK_RESULT_SRC__PC_PLUS_4;
      default:
        result_src = write_back_result_src_t'('0);
    endcase

  always_comb mem_write = opcode == SType;

  always_comb jump = opcode inside {JType, IType_jalr};

  always_comb branch = opcode == BType;

  always_comb alu_src = 1'bx; // TODO: revisit
endmodule
