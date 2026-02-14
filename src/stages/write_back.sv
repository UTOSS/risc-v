`default_nettype none

`include "src/interfaces/mem_to_wb_if.svh"

module write_back
  ( input var logic clk
  , input var logic reset

  , input mem_to_wb_t from_memory

  , output var data_t      result
  , output var logic [4:0] rd
  );

  assign rd = from_memory.rd;

  // TODO: `REULST_SRC__ALU_OUT` is no longer covered, revisit during integration
  always_comb
    case (from_memory.cfsm__result_src)
      WRITE_BACK_RESULT_SRC__ALU_RESULT: result = from_memory.alu_result;
      WRITE_BACK_RESULT_SRC__READ_DATA:  result = from_memory.read_data;
      WRITE_BACK_RESULT_SRC__PC_PLUS_4:  result = 32'hx; // TODO: address
      default:                           result = 32'hxxxxxxxx;
    endcase

endmodule
