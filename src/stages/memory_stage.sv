`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/mem_to_wb_if.svh"

module memory_stage
  ( input ex_to_mem_t ex_to_mem

  , output data_t      mem_write_data
  , output logic [3:0] mem_write_enable
  , output addr_t      mem_address

  , output mem_to_wb_t mem_to_wb
  );

  logic [1:0] byte_index;
  assign byte_index = mem_address[1:0];

  typedef enum logic [1:0]
    { BYTE = 2'b00
    , HALF = 2'b01
    , WORD = 2'b10
    } transfersize_t;

  transfersize_t transfersize;
  assign transfersize = transfersize_t'(ex_to_mem.funct3[1:0]);

  // determine which bytes of memory to write to
  always_comb
    if (ex_to_mem.mem_write == '0) mem_write_enable = 4'b0;
    else
      case ({transfersize, byte_index})
        {BYTE, 2'd0}:              mem_write_enable = 4'b0001;
        {BYTE, 2'd1}:              mem_write_enable = 4'b0010;
        {BYTE, 2'd2}:              mem_write_enable = 4'b0100;
        {BYTE, 2'd3}:              mem_write_enable = 4'b1000;
        {HALF, 2'd0}:              mem_write_enable = 4'b0011;
        {HALF, 2'd2}:              mem_write_enable = 4'b1100;
        {WORD, 2'd0}:              mem_write_enable = 4'b1111;
        default:                   mem_write_enable = 4'bxxxx;
      endcase

  // determine which bytes of the result to write to memory
  always_comb
    case (transfersize)
      BYTE:    mem_write_data = {4{ex_to_mem.write_data_e[ 7:0]}};
      HALF:    mem_write_data = {2{ex_to_mem.write_data_e[15:0]}};
      WORD:    mem_write_data = ex_to_mem.write_data_e;
      default: mem_write_data = 32'hxxxxxxxx;
    endcase

  assign mem_address = ex_to_mem.alu_result;

  // Combinational assignment to MEM_to_WB interface
  assign mem_to_wb.reg_write  = ex_to_mem.reg_write;
  assign mem_to_wb.result_src = ex_to_mem.result_src;
  assign mem_to_wb.rd         = ex_to_mem.rd;
  assign mem_to_wb.alu_result = ex_to_mem.alu_result;
  assign mem_to_wb.pc_cur     = ex_to_mem.pc_cur;
  assign mem_to_wb.pc_plus_4  = ex_to_mem.pc_plus_4;
  assign mem_to_wb.funct3     = ex_to_mem.funct3;

endmodule
