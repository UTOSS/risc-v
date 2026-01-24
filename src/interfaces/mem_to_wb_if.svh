`ifndef MEM_TO_WB_IF__HG
`define MEM_TO_WB_IF__HG

interface mem_to_wb_if;

  data_t read_data;
  data_t alu_result;
  logic [4:0] rd;

  modport from_memory
    ( input read_data
    , input alu_result
    , input rd
    );

  modport to_write_back
    ( output read_data
    , output alu_result
    , output rd
    );

endinterface

`endif MEM_TO_WB_IF__HG
