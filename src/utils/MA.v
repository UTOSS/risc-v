module MA #(parameter SIZE = 1024)
( input  [31:0] A
, input  [31:0] WD
, input  [3:0]  WE
//changed from 1 bit WE to 4 bit to address byteindex
, input  wire   CLK
, output [31:0] RD
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

    assign RD = M[A[31:2]]; // 2 LSBs used for byte addressing
    always @(posedge CLK) begin
      if (WE[0]) M[A[31:2]][7:0]   <= WD[7:0];
      if (WE[1]) M[A[31:2]][15:8]  <= WD[15:8];
      if (WE[2]) M[A[31:2]][23:16] <= WD[23:16];
      if (WE[3]) M[A[31:2]][31:24] <= WD[31:24];
    end

endmodule
