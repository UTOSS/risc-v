`include "src/headers/types.svh"

// an interface into a CSR plugin for direct access by hardware
interface csr_hw_request_if;

  logic  write_enable;
  data_t write_data;
  data_t read_data;

  modport plugin ( input  write_enable , input write_data  , output read_data );
  modport hw     ( output write_enable , output write_data , input  read_data );

endinterface
