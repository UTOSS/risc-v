`include "src/headers/types.svh"
`include "src/interfaces/mem_bus.svh"


module memory_map #( parameter SIZE = 1024 )
  ( input  wire    clk
  , mem_bus.memory d_bus
  , mem_bus.memory i_bus
  , output reg    [9:0] LEDR
  );

  reg [7:0] M0 [0:SIZE - 1] /* synthesis ram_init_file = "../../poc/poc0.mif" */;  // byte lane 0
  reg [7:0] M1 [0:SIZE - 1] /* synthesis ram_init_file = "../../poc/poc1.mif" */;  // byte lane 1
  reg [7:0] M2 [0:SIZE - 1] /* synthesis ram_init_file = "../../poc/poc2.mif" */;  // byte lane 2
  reg [7:0] M3 [0:SIZE - 1] /* synthesis ram_init_file = "../../poc/poc3.mif" */;  // byte lane 3

// only populate memory from MEM files if we are not synthesizing so that the simulation testbench
// can run
`ifndef UTOSS_RISCV_SYNTHESIS
  initial begin
    $readmemh("poc/poc0.mem", M0);
    $readmemh("poc/poc1.mem", M1);
    $readmemh("poc/poc2.mem", M2);
    $readmemh("poc/poc3.mem", M3);
  end
`endif

  reg [31:0] M [0:SIZE - 1];
  reg [31:0] mem_rdata;

  localparam bit [31:0] LEDR_ADDRESS = 32'h10000000;

  localparam int ADDR_LSB   = 2;
  localparam int ADDR_WIDTH = $clog2(SIZE);
  wire [ADDR_WIDTH - 1:0] mem_data_index  = d_bus.address[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];
  wire [ADDR_WIDTH - 1:0] mem_instr_index = i_bus.address[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];

  always @(*) begin
    case (d_bus.address)
      LEDR_ADDRESS: d_bus.read_data = {22'b0, LEDR};
      default:      d_bus.read_data = mem_rdata;
    endcase
  end

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
    case (d_bus.address)
      LEDR_ADDRESS: begin
        if (|d_bus.write_enable) LEDR <= d_bus.write_data[9:0];
      end
      default: begin
        if (d_bus.write_enable[0]) M0[mem_data_index] <= d_bus.write_data[7:0];
        if (d_bus.write_enable[1]) M1[mem_data_index] <= d_bus.write_data[15:8];
        if (d_bus.write_enable[2]) M2[mem_data_index] <= d_bus.write_data[23:16];
        if (d_bus.write_enable[3]) M3[mem_data_index] <= d_bus.write_data[31:24];

      end
    endcase
  end

endmodule
