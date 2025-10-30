module MA #( parameter SIZE = 1024 )
  ( input  wire   clk
  , input  addr_t address
  , input  data_t write_data
  , input  logic  write_enable
  , output data_t read_data
  );

    reg [31:0] M[0:SIZE -1];

    initial begin
      string mem_file;

      if ($value$plusargs("MEM=%s", mem_file)) begin
        $display("loading memory from <%s>", mem_file);
        $readmemh(mem_file, M);
        $display("memory loaded");
      end
    end

    assign read_data = M[address[31:2]]; // 2 LSBs used for byte addressing
    always @(posedge clk) begin
        if (write_enable) begin
            M[address[31:2]] <= write_data;
        end
    end

endmodule
