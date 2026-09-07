`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/mem_bus.svh"

module memory_map
  #( parameter SIZE = 128
  , parameter addr_t BOOT_ADDR = addr_t'(0)
  )
  ( input  wire        clk
  , input  wire        reset

  // this output port exists to avoid memory from getting optimized away since we dont have any
  // peripherals consuming the data at the top level
  , output reg  [31:0] gpio_out

  , mem_bus.memory d_bus
  , mem_bus.memory i_bus
  );

  reg [7:0] M0 [0:SIZE - 1];  // byte lane 0
  reg [7:0] M1 [0:SIZE - 1];  // byte lane 1
  reg [7:0] M2 [0:SIZE - 1];  // byte lane 2
  reg [7:0] M3 [0:SIZE - 1];  // byte lane 3

  reg [31:0] mem_rdata;

  localparam bit [31:0] GPIO_ADDRESS = 32'h10000000;

  localparam int ADDR_LSB   = 2;
  localparam int ADDR_WIDTH = $clog2(SIZE);

  addr_t d_offset;
  addr_t i_offset;

  assign d_offset = d_bus.address - BOOT_ADDR;
  assign i_offset = i_bus.address - BOOT_ADDR;

  wire [ADDR_WIDTH - 1:0] mem_data_index  = d_offset[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];
  wire [ADDR_WIDTH - 1:0] mem_instr_index = i_offset[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];

  wire unused = &{d_offset[`PROCESSOR_BITNESS - 1 : ADDR_LSB + ADDR_WIDTH]
                , d_offset[ADDR_LSB - 1 : 0]
                , i_offset[`PROCESSOR_BITNESS - 1 : ADDR_LSB + ADDR_WIDTH]
                , i_offset[ADDR_LSB - 1 : 0]};

  assign d_bus.read_data = (d_bus.address == GPIO_ADDRESS) ? gpio_out : mem_rdata;

  always @(posedge clk) begin
    i_bus.read_data <=
      { M3[mem_instr_index]
      , M2[mem_instr_index]
      , M1[mem_instr_index]
      , M0[mem_instr_index]
      };
    mem_rdata <=
      { M3[mem_data_index]
      , M2[mem_data_index]
      , M1[mem_data_index]
      , M0[mem_data_index]
      };
    if (reset) begin
      gpio_out <= '0;
    end else if (d_bus.address == GPIO_ADDRESS) begin
      if (|d_bus.write_enable) gpio_out <= d_bus.write_data;
    end else begin
      if (d_bus.write_enable[0]) M0[mem_data_index] <= d_bus.write_data[7:0];
      if (d_bus.write_enable[1]) M1[mem_data_index] <= d_bus.write_data[15:8];
      if (d_bus.write_enable[2]) M2[mem_data_index] <= d_bus.write_data[23:16];
      if (d_bus.write_enable[3]) M3[mem_data_index] <= d_bus.write_data[31:24];
    end
  end

endmodule
