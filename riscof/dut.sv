`timescale 1ns/1ps

module dut;

  reg clk;
  reg reset;

  top #( .MEM_SIZE ( 250000 /* 1MB */ ) )
    top
      ( .clk   ( clk   )
      , .reset ( reset )
      );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    reset <= `TRUE;
    @(posedge clk); #1;
    reset <= `FALSE;

    fork
      watch_tohost();
      watch_timeout();
    join_any

    $finish;
  end

  task watch_tohost();
    integer tohost;
    reg [31:0] tohost_data;

    $display("%m: waiting for tohost...");
    if ($value$plusargs("tohost=%h", tohost)) begin
      $display("%m: watching tohost at address <%0d>", tohost);
      forever begin
        @(posedge clk);
        tohost_data = top.memory.M[tohost];
        if (tohost_data != 0) begin
          $display("%m: memory[tohost] written <%0d> at time %t", tohost_data, $time);
          void'(extract_signature());
        end
      end
    end else begin
      $display("%m: tohost not specified.");
    end
  endtask

  task watch_timeout();
    $display("%m: waiting for timeout...");
    repeat (1) @(posedge clk);
    $display("%m: timeout reached");
    void'(extract_signature());
  endtask

  function bit extract_signature();
    integer begin_signature, end_signature;
    string sig_filename;
    integer sig_file, i, i_fixed;

    if (!$value$plusargs("begin_signature=%h", begin_signature)) begin
      $display("%m: begin_signature not specified.");
      return 1;
    end
    if (!$value$plusargs("end_signature=%h", end_signature)) begin
      $display("%m: end_signature not specified.");
      return 1;
    end
    if (!$value$plusargs("signature=%s", sig_filename)) begin
      $display("%m: signature file not specified.");
      return 1;
    end

    $display("%m: extracting signature from <%0x> to <%0x> to %s", begin_signature, end_signature, sig_file);

    sig_file = $fopen(sig_filename, "w");
    if (sig_file != 0) begin
      for (i = begin_signature; i < end_signature; i = i + 1) begin
        $fwrite(sig_file, "%08x\n", top.memory.M[i[31:2]]);
      end
      $fclose(sig_file);
      $display("%m: signature written to %s", sig_filename);
      return 0;
    end else begin
      $display("%m: failed to open signature file %s", sig_filename);
      return 1;
    end
  endfunction

endmodule
