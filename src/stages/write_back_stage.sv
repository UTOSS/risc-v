`default_nettype none

`include "src/headers/types.svh"
`include "src/timescale.svh"
`include "src/interfaces/mem_to_wb_if.svh"

module write_back_stage
  ( input  mem_to_wb_t     from_memory
  , input  data_t          data_from_memory
  , input  ex_to_mem_t     ex_to_mem
  , output var data_t      result
  , output var logic [4:0] rd
  );

  data_t alu_result_m;

  assign alu_result_m = from_memory.alu_result;

  data_t mem_result;

  MemoryLoader memory_loader
    ( .memory_data         ( data_from_memory            )
    , .memory_address      ( alu_result_m                )
    , .funct3              ( from_memory.funct3          )
    , .mem_load_result     ( mem_result                  )
    );

  assign rd = from_memory.rd;

  // TODO: `REULST_SRC__ALU_OUT` is no longer covered, revisit during integration
  always_comb
    case (from_memory.result_src)
      RESULT_SRC__ALU_RESULT: result = from_memory.alu_result;
      RESULT_SRC__READ_DATA:  result = mem_result;
      RESULT_SRC__PC_PLUS_4:  result = from_memory.pc_plus_4;
`ifdef UTOSS_RISCV__ZICSR_ENABLED
      RESULT_SRC__CSR_READ:   result = from_memory.csr_read_data;
`endif
      default:                result = 32'hxxxxxxxx;
    endcase

  wire unused = &{from_memory.reg_write
  , from_memory.pc_plus_4
  , ex_to_mem.write_data_e
  , ex_to_mem.rd
  , ex_to_mem.mem_write };

  wire _unused_ex_to_mem = &{1'b0, ex_to_mem};
  wire _unused_from_mem = &{1'b0, from_memory};


endmodule
