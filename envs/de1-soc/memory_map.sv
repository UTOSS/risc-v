`include "src/types.svh"

module memory_map #( parameter SIZE = 1024 )
  ( input  wire         clk

  , input  addr_t       address
  , input  data_t       write_data
  , input  logic  [3:0] write_enable
  , output data_t       read_data

  , output reg    [9:0] LEDR
  );

    reg [31:0] M[0:SIZE -1];

    // need to run make in the poc directory before this command can succeed
    initial $readmemh("poc/poc.mem", M);

    localparam bit [31:0] LEDR_ADDRESS = 32'h10000000;

    wire [31:0] mem_index = address[31:2] % SIZE;

    always @(posedge clk) begin
      case (address)
        LEDR_ADDRESS: read_data <= {22'b0, LEDR};
        default: read_data <= M[mem_index];
      endcase
    end

    always @(posedge clk) begin
      case (address)
        LEDR_ADDRESS: begin
          if (|write_enable) LEDR <= write_data[9:0];
        end
        default: begin
          // this is not compliant with our write_enable mechanism, and essentially breaks the
          // sub-word writing instructions (e.g. sb); however i could not get the per-byte writes on
          // de1-soc for some reason
          if (|write_enable) M[mem_index] <= write_data;
        end
      endcase
    end

endmodule
