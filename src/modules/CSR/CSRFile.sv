`include "src/timescale.svh"
`include "src/headers/types.svh"

module CSRFile
  ( input  csr_addr_t addr
  , input  logic      clk
  , input  logic      reset
  , input  logic      csr_write_enable
  , input  data_t     data_in
  , output data_t     data_out
  );

  reg [31:0] CSRMem [0:4095] /* synthesis ramstyle = M10K */;

  assign data_out = CSRMem[addr];

  always @(posedge clk) begin
    if (reset) begin
      integer i;
      for (i = 0; i < 4096; i = i + 1) begin
        CSRMem[i] <= 32'b0;
      end
    end else if (csr_write_enable) begin
      CSRMem[addr] <= data_in;
    end
  end

endmodule
