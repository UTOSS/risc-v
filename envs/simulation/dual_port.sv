`include "src/headers/types.svh"

module dual_port
  #( parameter SIZE = 1024 )
  ( input  wire         clk
  , input  addr_t       address
  , input  addr_t       instruction_address
  , input  data_t       write_data
  , input  wire   [3:0] write_enable
  , output data_t       read_data
  , output data_t       instruction_read_data
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
    read_data <= M[address[31:2]]; // 2 LSBs used for byte addressing
    instruction_read_data <= M[instruction_address[31:2]];
    if (write_enable[0]) M[address[31:2]][7:0]   <= write_data[7:0];
    if (write_enable[1]) M[address[31:2]][15:8]  <= write_data[15:8];
    if (write_enable[2]) M[address[31:2]][23:16] <= write_data[23:16];
    if (write_enable[3]) M[address[31:2]][31:24] <= write_data[31:24];
  end

//   MA #( .SIZE ( SIZE ) )
//     memory
//       ( .clk          ( clk                  )
//       , .address      ( address      )
//       , .write_data   ( write_data   )
//       , .write_enable ( write_enable )
//       , .read_data    ( read_data    )
//       );

// MA #( .SIZE ( SIZE ) )
//   imem
//     ( .clk          ( clk           )
//     , .address      ( instruction_address )
//     , .write_data   ( 32'hxxxx_xxxx )
//     , .write_enable ( 4'b0000       )
//     , .read_data    ( instruction_read_data    )
//     );
endmodule