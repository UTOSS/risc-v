`default_nettype none

`include "src/interfaces/mem_to_wb_if.svh"

module write_back
  ( input var logic clk
  , input var logic reset

  , mem_to_wb_if.from_memory from_memory

  , output var data_t      result
  , output var logic [4:0] rd
  );

  assign rd = from_memory.rd;

  // TODO: `REULST_SRC__ALU_OUT` is no longer covered, revisit during integration
  always_comb
    case (from_memory.cfsm__result_src)
      RESULT_SRC__DATA:       result = from_memory.read_data;
      RESULT_SRC__ALU_RESULT: result = from_memory.alu_result;
      default:                result = 32'hxxxxxxxx;
    endcase

endmodule
