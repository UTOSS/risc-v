`timescale 1ns/1ns
`include "test/utils.svh"
`include "src/ext/b/types.svh"

module zbs_tb;

import ext__b__types::*;

logic [31:0] reg1;
logic [31:0] reg2;
b_alu_control_t b_alu_control;
logic [31:0] out;

logic [31:0] expected;

zbs uut
  ( .reg1          ( reg1          )
  , .reg2          ( reg2          )
  , .b_alu_control ( b_alu_control )
  , .out           ( out           )
  );

initial begin

    // -------- bclr test --------
    reg1 = 32'b1010;
    reg2 = 32'd1;   // clear bit 1
    b_alu_control = B_ALU_CTRL__BCLR;
    #10;

    expected = reg1 & ~(32'h1 << reg2[4:0]);

    assert (out == expected) else
     $fatal("bclr failed: expected %b got %b", expected, out);


    // -------- bset test --------
    reg1 = 32'b1110;
    reg2 = 32'd0;   // set bit 0
    b_alu_control = B_ALU_CTRL__BSET;
    #10;

    expected = reg1 | (32'h1 << reg2[4:0]);

    assert (out == expected) else
     $fatal("bset failed: expected %b got %b", expected, out);


    // -------- binv test --------
    reg1 = 32'b1010;
    reg2 = 32'd1;
    b_alu_control = B_ALU_CTRL__BINV;
    #10;

    expected = reg1 ^ (32'h1 << reg2[4:0]);

    assert (out == expected) else
     $fatal("binv failed: expected %b got %b", expected, out);


    // -------- bext test --------
    reg1 = 32'b1010;
    reg2 = 32'd3;
    b_alu_control = B_ALU_CTRL__BEXT;
    #10;

    expected = {31'b0, reg1[reg2[4:0]]};

    assert (out == expected) else
     $fatal("bext failed: expected %b got %b", expected, out);

    // -------- Edge Cases ---------

    // Bit 0 boundary
    reg1 = 32'hFFFFFFFF;
    reg2 = 32'd0;
    b_alu_control = B_ALU_CTRL__BCLR; // bclr
    #10;

    expected = reg1 & ~(32'h1 << reg2[4:0]);

    assert (out == expected) else
     $fatal("corner case bit0 failed");


    // Bit 31 boundary
    reg1 = 32'hFFFFFFFF;
    reg2 = 32'd31;
    b_alu_control = B_ALU_CTRL__BCLR; // bclr
    #10;

    expected = reg1 & ~(32'h1 << reg2[4:0]);

    assert (out == expected) else
     $fatal("corner case bit31 failed");


    // ----------- Randomized Testing (Experimental) -----------

    repeat (1000) begin

                reg1 = $urandom;
                reg2 = $urandom % 32;

                // pick a Zbs operation without arithmetic on enums to avoid width expansion
                case ($urandom % 4)
                    0: b_alu_control = B_ALU_CTRL__BCLR;
                    1: b_alu_control = B_ALU_CTRL__BSET;
                    2: b_alu_control = B_ALU_CTRL__BINV;
                    3: b_alu_control = B_ALU_CTRL__BEXT;
                    default: b_alu_control = B_ALU_CTRL__BCLR;
                endcase

                #1;

                case (b_alu_control)

                        B_ALU_CTRL__BCLR: expected = reg1 & ~(32'h1 << reg2[4:0]);

                        B_ALU_CTRL__BSET: expected = reg1 | (32'h1 << reg2[4:0]);

                        B_ALU_CTRL__BINV: expected = reg1 ^ (32'h1 << reg2[4:0]);

                        B_ALU_CTRL__BEXT: expected = {31'b0, reg1[reg2[4:0]]};

                  default: expected = 32'd0;

        endcase

        assert (out == expected) else
          $fatal("random test failed: b_alu_control=%0d reg1=%h reg2=%d expected=%h got=%h"
                , b_alu_control, reg1, reg2, expected, out);

    end

    $display("All tests passed!");

    $finish;

end

`SETUP_VCD_DUMP(zbs_tb)


endmodule
