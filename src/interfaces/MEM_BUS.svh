`ifndef MEM_BUS
`define MEM_BUS

`include "src/headers/params.svh"
`include "src/headers/types.svh"

interface MEM_BUS;

  addr_t       memory__address;
  data_t       memory__write_data;
  logic  [3:0] memory__write_enable;
  data_t       memory__read_data;

  modport memory
    ( output memory__read_data
    , input  memory__address
    , input  memory__write_data
    , input  memory__write_enable
    );

  modport consumer
    ( input  memory__read_data
    , output memory__address
    , output memory__write_data
    , output memory__write_enable
    );

endinterface

`endif