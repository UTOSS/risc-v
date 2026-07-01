`ifndef MEM_BUS
`define MEM_BUS

`include "src/headers/params.svh"
`include "src/headers/types.svh"

interface MEM_BUS
    addr_t       memory__address; // out
    data_t       memory__write_data; // out
    logic  [3:0] memory__write_enable; // out
    data_t       memory__read_data; // in

    modport memory(
        input memory__read_data,
        output memory__address, // out
        output memory__write_data, // out
        output memory__write_enable // out
    ); 

    modport consumer(
        input memory__read_data,
        output memory__address, // out
        output memory__write_data, // out
        output memory__write_enable // out
    ); 
endinterface



