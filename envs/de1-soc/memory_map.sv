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

    localparam LEDR_ADDRESS = 32'h10000000;

    always @(*) begin
      case (address)
        LEDR_ADDRESS: read_data = {22'b0, LEDR};
        default: read_data = M[address[31:2]];
      endcase
    end

    always @(posedge clk) begin
      case (address)
        LEDR_ADDRESS: LEDR <= write_data[9:0];
        default: begin
          if (write_enable[0]) M[address[31:2]][7:0]   <= write_data[7:0];
          if (write_enable[1]) M[address[31:2]][15:8]  <= write_data[15:8];
          if (write_enable[2]) M[address[31:2]][23:16] <= write_data[23:16];
          if (write_enable[3]) M[address[31:2]][31:24] <= write_data[31:24];
        end
      endcase
    end

endmodule
