`default_nettype none

module write_back
  ( input var logic clk
  , input var logic reset

  , mem_to_wb_if.from_memory memory

  , output var data_t      result
  , output var logic [4:0] rd
  );

  assign rd = memory.rd;

  // TODO: `REULST_SRC__ALU_OUT` is no longer covered, revisit during integration
  always_comb
    case (cfsm__result_src)
      RESULT_SRC__DATA:       result = data;
      RESULT_SRC__ALU_RESULT: result = alu_result;
      default:                result = 32'hxxxxxxxx;
    endcase

endmodule
