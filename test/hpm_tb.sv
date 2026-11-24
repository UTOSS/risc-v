`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

`include "test/utils.svh"

// Checks the machine counters of the hardware performance monitor against the CSR read path that
// the core uses: mcycle counts cycles, minstret counts retire pulses, mhpmcounterN counts the event
// mhpmeventN selects, and both halves of every 64-bit counter are writable and readable.
module hpm_tb;

  import ext__zicsr__types::*;

  reg   clk = 0;
  reg   reset = `TRUE;
  logic retire = 0;

  ext__zicsr__types::csr_request_t    csr_request    = '0;
  ext__zicsr__types::csr_wb_request_t csr_wb_request = '0;

  data_t csr_data;
  data_t value_a = '0;
  data_t value_b = '0;

  csr_hw_request_if mcause_hw_request();
  csr_hw_request_if mtvec_hw_request();
  csr_hw_request_if mepc_hw_request();

  csr_data uut
    ( .clk   ( clk   )
    , .reset ( reset )

    , .csr_request    ( csr_request    )
    , .csr_wb_request ( csr_wb_request )
    , .retire         ( retire         )
    , .csr_data       ( csr_data       )

    , .mcause_hw_request ( mcause_hw_request )
    , .mepc_hw_request   ( mepc_hw_request   )
    , .mtvec_hw_request  ( mtvec_hw_request  )
    );

  // the test reads the CSR path directly, so nothing drives the hardware-request returns, and the
  // results are only consumed by the assertions of the ZICSR build
  wire unused = &{csr_data
  , value_a
  , value_b
  , mcause_hw_request.read_data
  , mepc_hw_request.read_data
  , mtvec_hw_request.read_data
  };

  task automatic tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic read_csr
    ( input  logic [11:0] address
    , output data_t       value
    );
    begin
      csr_request.address = csr_addr_t'(address);
      #1;
      value = csr_data;
    end
  endtask

  // The read path is asynchronous, so a write only shows up after the next clock edge.
  task automatic write_csr
    ( input logic [11:0] address
    , input data_t       data
    );
    begin
      csr_wb_request.address      = csr_addr_t'(address);
      csr_wb_request.data         = data;
      csr_wb_request.write_enable = 1'b1;
      tick();
      csr_wb_request.write_enable = 1'b0;
    end
  endtask

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

`ifdef UTOSS_RISCV__ENABLE_ZICSR_EXT
  initial begin
    tick();
    reset = `FALSE;
    tick();

    // mcycle counts clock cycles
    read_csr(12'hb00, value_a);
    tick();
    read_csr(12'hb00, value_b);
    `assert_equal(value_b, value_a + 32'd1)

    // a write to the low half wins over the increment of that cycle, and the next increment carries
    // into the high half
    write_csr(12'hb80, 32'h0000_0000);
    write_csr(12'hb00, 32'hffff_ffff);
    tick();
    read_csr(12'hb00, value_a);
    read_csr(12'hb80, value_b);
    `assert_equal(value_a, 32'h0000_0000)
    `assert_equal(value_b, 32'h0000_0001)

    // minstret counts retired instructions, not cycles
    write_csr(12'hb02, 32'h0000_0000);
    write_csr(12'hb82, 32'h0000_0000);
    repeat (3) begin
      retire = 1'b1;
      tick();
    end
    retire = 1'b0;
    repeat (2) tick();
    read_csr(12'hb02, value_a);
    `assert_equal(value_a, 32'd3)

    // mhpmevent3 selects the retired-instruction event for mhpmcounter3
    write_csr(12'h323, 32'd2);
    write_csr(12'hb03, 32'h0000_0000);
    read_csr(12'h323, value_a);
    `assert_equal(value_a, 32'd2)
    repeat (4) begin
      retire = 1'b1;
      tick();
    end
    retire = 1'b0;
    read_csr(12'hb03, value_a);
    `assert_equal(value_a, 32'd4)

    // mhpmevent4 selects the cycle event for mhpmcounter4
    write_csr(12'h324, 32'd1);
    write_csr(12'hb04, 32'h0000_0000);
    repeat (5) tick();
    read_csr(12'hb04, value_a);
    `assert_equal(value_a, 32'd5)

    // event 0 leaves the counter stopped
    write_csr(12'h325, 32'd0);
    write_csr(12'hb05, 32'h0000_0000);
    repeat (5) tick();
    read_csr(12'hb05, value_a);
    `assert_equal(value_a, 32'd0)

    // the high half of a counter is an ordinary read/write CSR as well
    write_csr(12'hb83, 32'hcafe_0000);
    read_csr(12'hb83, value_a);
    `assert_equal(value_a, 32'hcafe_0000)

    // mtime is not implemented, so it reads as zero instead of aliasing a counter
    read_csr(12'hb01, value_a);
    `assert_equal(value_a, 32'd0)

    $display("hpm_tb passed");
    $finish;
  end
`else
  initial begin
    $display("Skipping hpm_tb: build without ZICSR");
    $finish;
  end
`endif

  `SETUP_VCD_DUMP(hpm_tb)

endmodule
