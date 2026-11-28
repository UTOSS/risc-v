`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

// Machine counter with the RV32 layout of the hardware performance monitor: the low half of the
// counter lives at ADDRESS_LOW, the high half at ADDRESS_HIGH. mcycle, minstret and mhpmcounterN
// are all this module, they differ only in what drives `increment`.
module csr_hpm_counter
  #(parameter bit [11:0] ADDRESS_LOW  = 12'hb00
  , parameter bit [11:0] ADDRESS_HIGH = 12'hb80
  )
  ( input logic clk
  , input logic reset
  , input logic increment

  , input  csr_addr_t                          read_address
  , output data_t                              read_value

  , input  ext__zicsr__types::csr_wb_request_t csr_wb_request
  );

  logic [63:0] counter;
  logic        write_low;
  logic        write_high;

  // a CSR write to either half takes priority over the increment of that cycle, so software can
  // preset a counter without racing the event that it counts
  assign write_low  = csr_wb_request.write_enable && (csr_wb_request.address == csr_addr_t'(ADDRESS_LOW));
  assign write_high = csr_wb_request.write_enable && (csr_wb_request.address == csr_addr_t'(ADDRESS_HIGH));

  always_ff @(posedge clk)
    if (reset)
      counter <= '0;
    else if (write_low)
      counter[31:0] <= csr_wb_request.data;
    else if (write_high)
      counter[63:32] <= csr_wb_request.data;
    else if (increment)
      counter <= counter + 64'd1;

  assign read_value = (read_address == csr_addr_t'(ADDRESS_LOW))  ? counter[31:0]
                    : (read_address == csr_addr_t'(ADDRESS_HIGH)) ? counter[63:32]
                    : data_t'(0);

endmodule
