`include "src/types.svh"

module memory_map #( parameter SIZE = 1024 )
  ( input  wire         clk

  , input  addr_t       address
  , input  data_t       write_data
  , input  logic  [3:0] write_enable
  , output data_t       read_data
  , input  logic [31:0] dbg_regs [0:31]
  , input  addr_t       dbg_pc

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
    reg [31:0] mem_rdata;

    localparam bit [31:0] LEDR_ADDRESS = 32'h1000_0000;
    localparam bit [31:0] DBG_REG_BASE = 32'h2000_0000; // x0..x31
    localparam bit [31:0] DBG_PC_ADDR  = 32'h2000_0080; // to see where is the current pc

    localparam int ADDR_LSB   = 2;
    localparam int ADDR_WIDTH = $clog2(SIZE);
    wire [ADDR_WIDTH - 1 : 0] mem_index = address[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];

    wire dbg_reg_hit = (address[31:12] == DBG_REG_BASE[31:12]) && (address[11:7] == 5'd0); //between REG_BASE and use only 31 words
    wire [4:0] dbg_reg_idx = address[6:2];

    always @(*) begin
      case (address)
        LEDR_ADDRESS: read_data = {22'b0, LEDR};
        DBG_PC_ADDR:  read_data = dbg_pc;
        default: begin
          if (dbg_reg_hit && (dbg_reg_idx < 5'd32)) read_data = dbg_regs[dbg_reg_idx];
          else read_data = mem_rdata;
        end
      endcase
    end

    always @(posedge clk) begin
      mem_rdata <= { M3[mem_index], M2[mem_index], M1[mem_index], M0[mem_index] };

      case (address)
        LEDR_ADDRESS: begin
          if (|write_enable) LEDR <= write_data[9:0];
        end

        default: begin
          if (write_enable[0]) M0[mem_index] <= write_data[7:0];
          if (write_enable[1]) M1[mem_index] <= write_data[15:8];
          if (write_enable[2]) M2[mem_index] <= write_data[23:16];
          if (write_enable[3]) M3[mem_index] <= write_data[31:24];
        end
      endcase
    end

endmodule
