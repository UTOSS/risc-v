`ifndef MEM_TO_WB_IF__HG
`define MEM_TO_WB_IF__HG

interface mem_to_wb_if();

  result_src_t cfsm__result_src;
  logic RegWriteW;
  data_t read_data;
  data_t alu_result;
  logic [4:0] rd;

  modport from_memory
    ( input cfsm__result_src
    , input read_data
    , input alu_result
    , input rd
    , input RegWriteW
    );

  modport to_write_back
    ( output cfsm__result_src
    , output read_data
    , output alu_result
    , output rd
    , output RegWriteW
    );

endinterface

`endif
