`timescale 1ns/1ps


module MA #( parameter SIZE = 1024 )
  ( input  wire         clk

  /* verilator lint_off UNUSEDSIGNAL */
  , input  addr_t       address
  /* verilator lint_on UNUSEDSIGNAL */

  , input  data_t       write_data
  , input  wire   [3:0] write_enable
  , output data_t       read_data
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

  always @(posedge clk) begin
    read_data <= M[address[9:0]]; // 2 LSBs used for byte addressing
                                  // changed width from 32:2 to 9:0 to match "logic [1023:0] M;"

    if (write_enable[0]) M[address[11:2]][7:0]   <= write_data[7:0];
    if (write_enable[1]) M[address[11:2]][15:8]  <= write_data[15:8];
    if (write_enable[2]) M[address[11:2]][23:16] <= write_data[23:16];
    if (write_enable[3]) M[address[11:2]][31:24] <= write_data[31:24];
  end

endmodule
