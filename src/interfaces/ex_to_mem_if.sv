`include "src/headers/params.svh"
`include "src/headers/types.svh"

interface ex_to_mem_if (input clk);

    adr_src_t AdrSrc;
    pc_src_t pc_src;
    logic IRWrite;
    logic [3:0] MemWrite;
    logic RegWrite;
    result_src_t ResultSrc;
    logic [3:0] MemWriteByteAddress;
    logic [2:0] funct3;

    data_t alu_result;
    logic [4:0] rd;
    data_t rd2;
    addr_t pc_cur;

    modport Execute
    ( input clk
    , output AdrSrc
    , output pc_src
    , output IRWrite
    , output MemWrite
    , output RegWrite
    , output ResultSrc
    , output MemWriteByteAddress
    , output funct3
    , output alu_result
    , output rd
    , output rd2
    , output pc_cur
    );

    modport Memory
    ( input clk
    , input AdrSrc
    , input pc_src
    , input IRWrite
    , input MemWrite
    , input RegWrite
    , input ResultSrc
    , input MemWriteByteAddress
    , input funct3
    , input alu_result
    , input rd
    , input rd2
    , input pc_cur
    );

endinterface