`include "src/headers/types.svh"
`include "src/interfaces/mem_bus.svh"

module memory_map #( parameter int SIZE = 1024 )
  ( input  wire       clk
  , output reg  [3:0] led
  , output reg  [7:0] gpio

  , mem_bus.memory d_bus
  , mem_bus.memory i_bus
  );

  reg [31:0] M [0:SIZE - 1];

`ifdef UTOSS_RISCV_SYNTHESIS
  initial begin
    $readmemh("../poc/poc.mem", M);
  end
`else
  initial begin
    $readmemh("poc/poc.mem", M);
  end
`endif

  reg [31:0] mem_rdata;

  localparam bit [31:0] LED_ADDRESS  = 32'h10000000;
  localparam bit [31:0] GPIO_ADDRESS = 32'h10000004;

  localparam int ADDR_LSB   = 2;
  localparam int ADDR_WIDTH = $clog2(SIZE);
  wire [ADDR_WIDTH - 1:0] mem_data_index  = d_bus.address[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];
  wire [ADDR_WIDTH - 1:0] mem_instr_index = i_bus.address[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];

  always @(*) begin
    case (d_bus.address)
      LED_ADDRESS:  d_bus.read_data = {28'b0, led};
      GPIO_ADDRESS: d_bus.read_data = {24'b0, gpio};
      default:      d_bus.read_data = mem_rdata;
    endcase
  end

  always @(posedge clk) begin
    i_bus.read_data <= M[mem_instr_index];
    mem_rdata       <= M[mem_data_index];
    case (d_bus.address)
      LED_ADDRESS: begin
        if (|d_bus.write_enable) led <= d_bus.write_data[3:0];
      end
      GPIO_ADDRESS: begin
        if (|d_bus.write_enable) gpio <= d_bus.write_data[7:0];
      end
      default: begin
        if (d_bus.write_enable[0]) M[mem_data_index][7:0]   <= d_bus.write_data[7:0];
        if (d_bus.write_enable[1]) M[mem_data_index][15:8]  <= d_bus.write_data[15:8];
        if (d_bus.write_enable[2]) M[mem_data_index][23:16] <= d_bus.write_data[23:16];
        if (d_bus.write_enable[3]) M[mem_data_index][31:24] <= d_bus.write_data[31:24];
      end
    endcase
  end

endmodule
