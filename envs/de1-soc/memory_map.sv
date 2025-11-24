module memory_map #( parameter SIZE = 1024 )
  ( input  wire   clk

  , input  addr_t address
  , input  data_t write_data
  , input  logic  write_enable
  , output data_t read_data

  , output reg [9:0] LEDR
  );

    reg [31:0] M[0:SIZE -1];

    // need to run make in the poc directory before this command can succeed

    initial begin

      $readmemh("envs/de1-soc/poc/poc.mem", M);
    end

    localparam LEDR_ADDRESS = 32'h10000000;

    wire [31:0] word_addr = address[31:2];
    wire [31:0] mem_index = word_addr % SIZE;

    always_comb begin
      case (address)
        LEDR_ADDRESS: read_data = {22'b0, LEDR};
        default: read_data = M[mem_index];
      endcase
    end

    always @(posedge clk) begin
      case (address)
        LEDR_ADDRESS: LEDR <= write_data[9:0];
        default: begin
          if (write_enable) begin
              M[mem_index] <= write_data;
          end
        end
      endcase
    end

endmodule
