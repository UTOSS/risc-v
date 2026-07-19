`include "src/headers/types.svh"

// a dual-read single-write memory block that we use with our core in simulation environment
module memory
  #( parameter SIZE = 1024 )
  ( input  wire         clk
  , input  addr_t       address
  , input  addr_t       instruction_address
  , input  data_t       write_data
  , input  wire   [3:0] write_enable
  , output data_t       read_data
  , output data_t       instruction_read_data
  );


  reg [31:0] M[0:SIZE -1];

`ifndef UTOSS_RISCV_HARDENING
  initial begin
    string mem_file;

    if ($value$plusargs("MEM=%s", mem_file)) begin
      $display("loading memory from <%s>", mem_file);
      $readmemh(mem_file, M);
      $display("memory loaded");
    end
  end
`endif

  localparam int unsigned SIZE_W = $clog2(SIZE);

  if (SIZE_W >= `PROCESSOR_BITNESS) begin: l_check_size
    initial begin
      $fatal(1, "memory is too large to be addressed by a %d-bit address", `PROCESSOR_BITNESS);
    end
  end

  wire unused =
    &{address[`PROCESSOR_BITNESS -1:SIZE_W]            , address[1:0]
    , instruction_address[`PROCESSOR_BITNESS -1:SIZE_W], instruction_address[1:0]
    };

  always @(posedge clk) begin
    read_data <= M[address[SIZE_W +1:2]]; // 2 LSBs used for byte addressing
    instruction_read_data <= M[instruction_address[SIZE_W +1:2]];
    if (write_enable[0]) M[address[SIZE_W +1:2]][7:0]   <= write_data[7:0];
    if (write_enable[1]) M[address[SIZE_W +1:2]][15:8]  <= write_data[15:8];
    if (write_enable[2]) M[address[SIZE_W +1:2]][23:16] <= write_data[23:16];
    if (write_enable[3]) M[address[SIZE_W +1:2]][31:24] <= write_data[31:24];
  end

endmodule
