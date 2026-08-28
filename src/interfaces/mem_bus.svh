`ifndef IF_MEM_BUS__HG
`define IF_MEM_BUS__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"

interface mem_bus;

  addr_t       address;
  data_t       write_data;
  logic  [3:0] write_enable;
  data_t       read_data;

  modport memory
    ( output read_data
    , input  address
    , input  write_data
    , input  write_enable
    );

  modport consumer
    ( input  read_data
    , output address
    , output write_data
    , output write_enable
    );

endinterface

`endif
