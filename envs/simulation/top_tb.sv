/* verilator lint_off TIMESCALEMOD */
`include "src/timescale.svh"
`include "src/headers/types.svh"

module top_tb
  #( parameter addr_t BOOT_ADDR = addr_t'(0) );

  logic clk;
  logic reset;

  top
    #( .BOOT_ADDR ( BOOT_ADDR ) )
    uut
    ( .clk   ( clk   )
    , .reset ( reset )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  function automatic string reg_name(input reg_t reg_idx);
    case (reg_idx)
      5'd0:  reg_name = "zero";
      5'd1:  reg_name = "ra";
      5'd2:  reg_name = "sp";
      5'd3:  reg_name = "gp";
      5'd4:  reg_name = "tp";
      5'd5:  reg_name = "t0";
      5'd6:  reg_name = "t1";
      5'd7:  reg_name = "t2";
      5'd8:  reg_name = "s0";
      5'd9:  reg_name = "s1";
      5'd10: reg_name = "a0";
      5'd11: reg_name = "a1";
      5'd12: reg_name = "a2";
      5'd13: reg_name = "a3";
      5'd14: reg_name = "a4";
      5'd15: reg_name = "a5";
      5'd16: reg_name = "a6";
      5'd17: reg_name = "a7";
      5'd18: reg_name = "s2";
      5'd19: reg_name = "s3";
      5'd20: reg_name = "s4";
      5'd21: reg_name = "s5";
      5'd22: reg_name = "s6";
      5'd23: reg_name = "s7";
      5'd24: reg_name = "s8";
      5'd25: reg_name = "s9";
      5'd26: reg_name = "s10";
      5'd27: reg_name = "s11";
      5'd28: reg_name = "t3";
      5'd29: reg_name = "t4";
      5'd30: reg_name = "t5";
      5'd31: reg_name = "t6";
      default: reg_name = "x?";
    endcase
  endfunction

  initial begin
    integer max_cycles;
    integer cycle;
    integer loop_count;
    integer r;
    string vcd_path;

    if ($value$plusargs("VCD_PATH=%s", vcd_path)) begin
      $dumpfile(vcd_path);
      $dumpvars(0, top_tb);
    end

    if (!$value$plusargs("CYCLES=%d", max_cycles)) begin
      max_cycles = 100;
    end

    reset <= 1'b1;
    repeat (2) @(posedge clk);
    #1;
    reset <= 1'b0;

    loop_count = 0;

    for (cycle = 0; cycle < max_cycles; cycle = cycle + 1) begin
      @(posedge clk);
      #1;

      // Detect self-loop (e.g. `done: j done` where jump target equals jump PC)
      if (uut.core.ex_to_if_out.pc_src &&
          (uut.core.ex_to_if_out.pc_target == uut.core.id_to_ex_reg.pc_cur)) begin
        loop_count = loop_count + 1;
        if (loop_count >= 2) begin
          $display("\n[SIMULATION] Self-loop / termination detected at PC 0x%08h after %0d cycles."
                  , uut.core.id_to_ex_reg.pc_cur
                  , cycle
                  );
          break;
        end
      end
    end

    if (cycle >= max_cycles) begin
      $display("\n[SIMULATION] Simulation reached cycle limit (%0d cycles).", max_cycles);
    end

    // Allow pipeline to flush writebacks
    repeat (4) @(posedge clk);

    $display("\n=======================================================");
    $display("                REGISTER FILE DUMP");
    $display("=======================================================");
    for (r = 0; r < 32; r = r + 1) begin
      if (uut.core.u_decode_stage.RegFile.RFMem[r] !== 32'd0) begin
        $display("  x%-2d (%-4s) = 0x%08h (%0d)"
                , r
                , reg_name(reg_t'(r))
                , uut.core.u_decode_stage.RegFile.RFMem[r]
                , $signed(uut.core.u_decode_stage.RegFile.RFMem[r])
                );
      end
    end
    $display("=======================================================\n");

    $finish;
  end

endmodule
