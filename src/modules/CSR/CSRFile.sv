`include "src/timescale.svh"
`include "src/headers/types.svh"

module CSRFile
  ( input  csr_addr_t read_addr
  , input  csr_addr_t write_addr
  , input  logic      clk
  , input  logic      reset
  , input  logic      csr_write_enable
  , input  data_t     data_in
  , output data_t     data_out
  );

  reg [31:0] CSRMem [0:`NUMBER_OF_CSRS-1];

  assign data_out = CSRMem[read_addr];

  always @(posedge clk) begin
    if (reset) begin
      integer i;
      for (i = 0; i < `NUMBER_OF_CSRS; i = i + 1) begin
        CSRMem[i] <= 32'b0;
      end
    end else if (csr_write_enable) begin
      CSRMem[write_addr] <= data_in;
    end
  end

endmodule
