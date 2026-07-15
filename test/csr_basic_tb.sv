`include "src/timescale.svh"

`include "test/utils.svh"

module csr_basic_tb;

  reg clk;
  reg reset;

  top uut
    ( .clk   ( clk   )
    , .reset ( reset )
    );

  function automatic instr_t encode_csr
    ( input logic [11:0] csr
    , input logic [4:0]   rd
    , input logic [2:0]   funct3
    , input logic [4:0]   rs1
    );
    begin
      encode_csr = {csr, rs1, funct3, rd, 7'h73};
    end
  endfunction

  task automatic tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

`ifdef UTOSS_RISCV__ZICSR_ENABLED
  initial begin
    static bit saw_csr_stall = 0;

    reset = `TRUE;

    tick();
    reset = `FALSE;

    // mstatus is a convenient architectural CSR for basic read/write tests.
    uut.u_memory.M[0] = encode_csr(12'h300, 5'd3, 3'b001, 5'd1); // csrrw x3, mstatus, x1
    uut.u_memory.M[1] = encode_csr(12'h300, 5'd4, 3'b010, 5'd2); // csrrs x4, mstatus, x2
    uut.u_memory.M[2] = encode_csr(12'h300, 5'd5, 3'b011, 5'd2); // csrrc x5, mstatus, x2
    uut.u_memory.M[3] = 32'h00000013; // nop

    uut.core.u_decode_stage.RegFile.RFMem[1] = 32'h1111_1111;
    uut.core.u_decode_stage.RegFile.RFMem[2] = 32'h2222_2222;
    uut.core.u_decode_stage.u_csr_file.CSRMem[12'h300] = 32'h1234_5678;

    repeat (20) begin
      tick();
      if (uut.core.stall_d) saw_csr_stall = 1;
    end

    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[3], 32'h1234_5678)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[4], 32'h1111_1111)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[5], 32'h3333_3333)
    `assert_equal(uut.core.u_decode_stage.u_csr_file.CSRMem[12'h300], 32'h1111_1111)
    `assert_equal(saw_csr_stall, 1'b1)

    $finish;
  end
`else
  initial begin
    $display("Skipping csr_basic_tb: build without ZICSR");
    $finish;
  end
`endif

  `SETUP_VCD_DUMP(csr_basic_tb)

endmodule
