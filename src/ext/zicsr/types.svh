`ifndef EXT__ZICSR__TYPES
`define EXT__ZICSR__TYPES

`include "src/headers/types.svh"

/* verilator lint_off DECLFILENAME */
package ext__zicsr__types;
/* verilator lint_on DECLFILENAME */

  typedef enum logic [1:0]
    { CSR_OP__NONE  = 2'b00
    , CSR_OP__WRITE = 2'b01 // csrrw / csrrwi
    , CSR_OP__SET   = 2'b10 // csrrs / csrrsi
    , CSR_OP__CLEAR = 2'b11 // csrrc / csrrci
    } csr_op_t;

  // Produced by `csr_decode` in ID; used to read the CSR in ID and carried down the pipeline so that
  // `csr_wb` can compute the write-back in WB
  typedef struct packed {
    logic      valid;        // instruction is a CSR instruction
    csr_op_t   op;
    csr_addr_t address;
    data_t     operand;      // rs1 value, or zero-extended uimm for the immediate forms
    logic      write_intent; // CSR will be written in WB; also used by the hazard unit
  } csr_request_t;

  // Produced by `csr_data` in ID (asynchronous read) and carried down the pipeline
  typedef struct packed {
    data_t value;            // contents of the CSR at `csr_request_t.address`
  } csr_data_t;

  // Produced by `csr_wb` in WB and fed back into `csr_data` (not pipelined)
  typedef struct packed {
    csr_addr_t address;
    data_t     data;
    logic      write_enable;
  } csr_wb_request_t;

endpackage

`endif
