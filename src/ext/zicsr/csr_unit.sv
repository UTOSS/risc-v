`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

// Decode-stage portion of the Zicsr extension: decodes the CSR instruction and reads the CSR; the
// write happens later, in WB, via `csr_wb_request` (see `csr_wb`)
module csr_unit
  ( input logic clk
  , input logic reset

  , input  opcode_t                            opcode
  , input  logic [2:0]                         funct3
  , input  logic [4:0]                         rs1_or_uimm
  , input  csr_addr_t                          csr_addr
  , input  data_t                              rs1_data
  , input  ext__zicsr__types::csr_wb_request_t csr_wb_request

  , output ext__zicsr__types::csr_request_t    csr_request
  , output ext__zicsr__types::csr_data_t       csr_data
  );

  csr_decode u_csr_decode
    ( .opcode      ( opcode      )
    , .funct3      ( funct3      )
    , .rs1_or_uimm ( rs1_or_uimm )
    , .csr_addr    ( csr_addr    )
    , .rs1_data    ( rs1_data    )
    , .csr_request ( csr_request )
    );

  csr_data u_csr_data
    ( .clk            ( clk            )
    , .reset          ( reset          )
    , .csr_request    ( csr_request    )
    , .csr_wb_request ( csr_wb_request )
    , .csr_data       ( csr_data       )
    );

endmodule
