`include "src/timescale.svh"

`include "test/utils.svh"

module csr_immediate_hazard_tb;

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

    // mtvec is used here to exercise the immediate CSR forms and zero-immediate write suppression.
    uut.u_memory.M[0] = encode_csr(12'h305, 5'd6, 3'b101, 5'd7); // csrrwi x6, mtvec, 7
    uut.u_memory.M[1] = encode_csr(12'h305, 5'd7, 3'b110, 5'd0); // csrrsi x7, mtvec, 0
    uut.u_memory.M[2] = encode_csr(12'h305, 5'd8, 3'b111, 5'd1); // csrrci x8, mtvec, 1
    uut.u_memory.M[3] = 32'h00000013; // nop

    uut.core.u_decode_stage.u_csr_file.CSRMem[12'h305] = 32'h0000_0055;

    repeat (20) begin
      tick();
      if (uut.core.stall_d) saw_csr_stall = 1;
    end

    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[6], 32'h0000_0055)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[7], 32'h0000_0007)
    `assert_equal(uut.core.u_decode_stage.RegFile.RFMem[8], 32'h0000_0007)
    `assert_equal(uut.core.u_decode_stage.u_csr_file.CSRMem[12'h305], 32'h0000_0006)
    `assert_equal(saw_csr_stall, 1'b1)

    $finish;
  end
`else
  initial begin
    $display("Skipping csr_immediate_hazard_tb: build without UTOSS_RISCV__ZICSR_ENABLED");
    $finish;
  end
`endif

  `SETUP_VCD_DUMP(csr_immediate_hazard_tb)

endmodule
