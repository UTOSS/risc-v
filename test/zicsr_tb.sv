`include "src/timescale.svh"

`include "test/utils.svh"

module zicsr_tb;

  reg clk;
  reg reset = `TRUE;

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
    static bit saw_csr_stall    = 0;
    static bit saw_csr_flush_e  = 0;

    tick();
    reset = `FALSE;

    // Program: exercise register and immediate CSR forms, x0 destinations, and zero-source reads.
    uut.u_memory.M[0]  = encode_csr(12'h300, 5'd8,  3'b001, 5'd1); // csrrw  s0, mstatus, x1
    uut.u_memory.M[1]  = encode_csr(12'h300, 5'd9,  3'b010, 5'd2); // csrrs  s1, mstatus, x2
    uut.u_memory.M[2]  = encode_csr(12'h300, 5'd18, 3'b011, 5'd3); // csrrc  s2, mstatus, x3
    uut.u_memory.M[3]  = encode_csr(12'h300, 5'd0,  3'b001, 5'd7); // csrrw  x0, mstatus, x7
    uut.u_memory.M[4]  = encode_csr(12'h300, 5'd19, 3'b010, 5'd0); // csrrs  s3, mstatus, x0
    uut.u_memory.M[5]  = encode_csr(12'h305, 5'd20, 3'b101, 5'd7); // csrrwi s4, mtvec, 7
    uut.u_memory.M[6]  = encode_csr(12'h305, 5'd21, 3'b110, 5'd0); // csrrsi s5, mtvec, 0
    uut.u_memory.M[7]  = encode_csr(12'h305, 5'd22, 3'b111, 5'd1); // csrrci s6, mtvec, 1
    uut.u_memory.M[8]  = encode_csr(12'h305, 5'd23, 3'b010, 5'd0); // csrrs  s7, mtvec, x0
    uut.u_memory.M[9]  = encode_csr(12'h300, 5'd24, 3'b010, 5'd0); // csrrs  s8, mstatus, x0
    uut.u_memory.M[10] = encode_csr(12'h305, 5'd25, 3'b010, 5'd0); // csrrs  s9, mtvec, x0
    uut.u_memory.M[11] = encode_csr(12'h300, 5'd26, 3'b001, 5'd4); // csrrw  s10, mstatus, x4
    uut.u_memory.M[12] = 32'h00000013; // nop

    uut.core.u_decode_stage.RegFile.RFMem[1]  = 32'h1111_1111;
    uut.core.u_decode_stage.RegFile.RFMem[2]  = 32'h2222_2222;
    uut.core.u_decode_stage.RegFile.RFMem[3]  = 32'h0000_0007;
    uut.core.u_decode_stage.RegFile.RFMem[4]  = 32'h6767_6767;
    uut.core.u_decode_stage.RegFile.RFMem[7]  = 32'h0000_000f;
    uut.core.u_decode_stage.u_csr_file.CSRMem[12'h300] = 32'h1234_5678;
    uut.core.u_decode_stage.u_csr_file.CSRMem[12'h305] = 32'h0000_0055;

    repeat (80) begin
      tick();
      if (uut.core.stall_d)    saw_csr_stall   = 1;
      if (uut.core.flush_e)    saw_csr_flush_e = 1;
    end

    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[8],  32'h1234_5678)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[9],  32'h1111_1111)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[18], 32'h3333_3333)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[19], 32'h0000_000f)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[20], 32'h0000_0055)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[21], 32'h0000_0007)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[22], 32'h0000_0007)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[23], 32'h0000_0006)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[24], 32'h0000_000f)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[25], 32'h0000_0006)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[26], 32'h0000_000f)
    `assert_equal(uut.core.u_decode_stage.u_csr_file.CSRMem[12'h300], 32'h6767_6767)
    `assert_equal(uut.core.u_decode_stage.u_csr_file.CSRMem[12'h305], 32'h0000_0006)
    `assert_equal(saw_csr_stall,   1'b1)
    `assert_equal(saw_csr_flush_e, 1'b1)

    $finish;
  end
`else
  initial begin
    $display("Skipping zicsr_comprehensive_tb: build without ZICSR");
    $finish;
  end
`endif

  `SETUP_VCD_DUMP(zicsr_comprehensive_tb)

endmodule
