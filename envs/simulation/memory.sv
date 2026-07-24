`include "src/headers/types.svh"
`include "src/interfaces/mem_bus.svh"

// a dual-read single-write memory block that we use with our core in simulation environment
module memory
  #( parameter SIZE = 1024
  , parameter addr_t BOOT_ADDR = addr_t'(0)
  )
  ( input wire clk

  , mem_bus.memory i_bus
  , mem_bus.memory d_bus
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

  addr_t d_base_address;
  addr_t i_base_address;

  assign d_base_address = d_bus.address - BOOT_ADDR;
  assign i_base_address = i_bus.address - BOOT_ADDR;

  wire unused = &{d_base_address[`PROCESSOR_BITNESS -1:SIZE_W]
                , d_base_address[1:0]
                , i_base_address[`PROCESSOR_BITNESS -1:SIZE_W]
                , i_base_address[1:0]};

  always @(posedge clk) begin
    d_bus.read_data <= M[d_base_address[SIZE_W + 1:2]];
    i_bus.read_data <= M[i_base_address[SIZE_W + 1:2]];

    if (d_bus.write_enable[0]) M[d_base_address[SIZE_W +1:2]][7:0] <= d_bus.write_data[7:0];
    if (d_bus.write_enable[1]) M[d_base_address[SIZE_W +1:2]][15:8] <= d_bus.write_data[15:8];
    if (d_bus.write_enable[2]) M[d_base_address[SIZE_W +1:2]][23:16] <= d_bus.write_data[23:16];
    if (d_bus.write_enable[3]) M[d_base_address[SIZE_W +1:2]][31:24] <= d_bus.write_data[31:24];
  end

endmodule
