`include "src/timescale.svh"

`include "test/utils.svh"

module div_tb;

  localparam bit [1:0] DIV  = 2'b00;
  localparam bit [1:0] DIVU = 2'b01;
  localparam bit [1:0] REM  = 2'b10;
  localparam bit [1:0] REMU = 2'b11;

  reg clk;
  reg rst_n;
  reg start_i;
  reg[1:0] op_i;
  reg[31:0] rs1_i;
  reg[31:0] rs2_i;

  wire[31:0] result_o;
  wire ready_o;
  wire busy_o;

  integer passes;
  integer fails;

  div uut
    ( .clk ( clk )
    , .rst_n ( rst_n )
    , .start_i ( start_i )
    , .op_i ( op_i )
    , .rs1_i ( rs1_i )
    , .rs2_i ( rs2_i )
    , .result_o ( result_o )
    , .ready_o ( ready_o )
    , .busy_o ( busy_o )
    );

  task automatic run
    ( input [1:0] op
    , input [31:0] a
    , input [31:0] b
    , input [31:0] exp
    , input [255:0] name
    );
    integer guard;
    begin
      @(posedge clk); #1;
      rs1_i = a; rs2_i = b; op_i = op; start_i = 1'b1;
      @(posedge clk); #1;
      start_i = 1'b0;

      guard = 0;
      #1;
      while (!ready_o && guard < 64) begin
        @(posedge clk); #1;
        guard = guard + 1;
      end

      if (guard >= 64) begin
        fails = fails + 1;
        $display("FAIL %0s: timed out, ready_o never asserted (busy_o=%b)", name, busy_o);
      end
      else if (result_o !== exp) begin
        fails = fails + 1;
        $display("FAIL %0s: got %h expected %h (%0d cycles)", name, result_o, exp, guard);
      end
      else begin
        passes = passes + 1;
        $display("pass %0s: %h in %0d cycles", name, result_o, guard);
      end
    end
  endtask

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin

    rst_n = 1'b0;
    start_i = 1'b0;
    op_i = 2'b00;
    rs1_i = 32'b0;
    rs2_i = 32'b0;
    passes = 0;
    fails = 0;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // unsigned first -- no sign logic involved, so a failure here is the loop
    run(DIVU, 32'd200, 32'd13, 32'd15, "divu 200/13");
    run(REMU, 32'd200, 32'd13, 32'd5, "remu 200%13");
    run(DIVU, 32'd1, 32'd1, 32'd1, "divu 1/1");
    run(DIVU, 32'd0, 32'd7, 32'd0, "divu 0/7");
    run(DIVU, 32'd7, 32'd9, 32'd0, "divu 7/9 divisor bigger");
    run(REMU, 32'd7, 32'd9, 32'd7, "remu 7%9 divisor bigger");
    run(DIVU, 32'hFFFF_FFFF, 32'd2, 32'h7FFF_FFFF, "divu max/2");
    run(REMU, 32'hFFFF_FFFF, 32'd2, 32'd1, "remu max%2");
    run(DIVU, 32'd13, 32'd13, 32'd1, "divu equal operands");
    run(REMU, 32'd13, 32'd13, 32'd0, "remu equal operands");

    // signed, all four sign combinations
    run(DIV, 32'd200, 32'd13, 32'd15, "div 200/13");
    run(DIV, -32'd7, 32'd2, -32'd3, "div -7/2");
    run(DIV, 32'd7, -32'd2, -32'd3, "div 7/-2");
    run(DIV, -32'd7, -32'd2, 32'd3, "div -7/-2");

    // remainder takes the sign of the DIVIDEND, not the quotient
    run(REM, 32'd7, 32'd2, 32'd1, "rem 7%2");
    run(REM, -32'd7, 32'd2, -32'd1, "rem -7%2");
    run(REM, 32'd7, -32'd2, 32'd1, "rem 7%-2");
    run(REM, -32'd7, -32'd2, -32'd1, "rem -7%-2");

    // most negative value as an ordinary dividend
    run(DIV, 32'h8000_0000, 32'd2, 32'hC000_0000, "div min/2");
    run(REM, 32'h8000_0000, 32'd2, 32'd0, "rem min%2");

    // divide by zero
    run(DIV, 32'd200, 32'd0, 32'hFFFF_FFFF, "div by zero");
    run(DIVU, 32'd200, 32'd0, 32'hFFFF_FFFF, "divu by zero");
    run(REM, 32'd200, 32'd0, 32'd200, "rem by zero");
    run(REMU, 32'd200, 32'd0, 32'd200, "remu by zero");
    run(REM, -32'd200, 32'd0, -32'd200, "rem by zero negative dividend");

    // signed overflow: most negative / -1
    run(DIV, 32'h8000_0000, 32'hFFFF_FFFF, 32'h8000_0000, "div overflow");
    run(REM, 32'h8000_0000, 32'hFFFF_FFFF, 32'd0, "rem overflow");

    // back to back, no idle gap
    run(DIVU, 32'd100, 32'd7, 32'd14, "back to back a");
    run(DIVU, 32'd99, 32'd7, 32'd14, "back to back b");

    // start_i while busy must be ignored, operands must not be overwritten
    @(posedge clk); #1;
    rs1_i = 32'd200; rs2_i = 32'd13; op_i = DIVU; start_i = 1'b1;
    @(posedge clk); #1;
    rs1_i = 32'd999; rs2_i = 32'd3;
    @(posedge clk); #1;
    if (!busy_o) begin
      fails = fails + 1;
      $display("FAIL busy_o low mid-operation");
    end
    start_i = 1'b0;
    while (!ready_o) @(posedge clk);
    #1;
    if (result_o !== 32'd15) begin
      fails = fails + 1;
      $display("FAIL start while busy: operands overwritten, got %h expected 0000000f", result_o);
    end
    else begin
      passes = passes + 1;
      $display("pass start while busy ignored");
    end

    // reset mid-iteration must return to idle
    @(posedge clk); #1;
    rs1_i = 32'd200; rs2_i = 32'd13; op_i = DIVU; start_i = 1'b1;
    @(posedge clk); #1;
    start_i = 1'b0;
    repeat (8) @(posedge clk);
    rst_n = 1'b0;
    @(posedge clk); #1;
    if (busy_o) begin
      fails = fails + 1;
      $display("FAIL reset mid-iteration left busy_o high");
    end
    else begin
      passes = passes + 1;
      $display("pass reset mid-iteration");
    end
    rst_n = 1'b1;
    @(posedge clk);

    run(DIVU, 32'd200, 32'd13, 32'd15, "divu after reset");

    $display("");
    $display("%0d passed, %0d failed", passes, fails);

    $finish;

  end

  `SETUP_VCD_DUMP(div_tb)

endmodule
