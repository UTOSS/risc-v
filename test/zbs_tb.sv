`timescale 1ns/1ns
`include "test/utils.svh"

module zbs_tb;

logic [31:0] reg1;
logic [31:0] reg2;
alu_control_t inst;
logic [31:0] out;

logic [31:0] expected;

zbs uut
  ( .reg1 ( reg1 )
  , .reg2 ( reg2 )
  , .inst ( inst )
  , .out  ( out  )
);

initial begin

    // -------- bclr test --------
    reg1 = 32'b1010;
    reg2 = 32'd1;   // clear bit 1
    inst = ALU_CONTROL_BCLR;
    #10;

    expected = reg1 & ~(32'h1 << reg2[4:0]);

    assert (out == expected) else
     $fatal("bclr failed: expected %b got %b", expected, out);


    // -------- bset test --------
    reg1 = 32'b1110;
    reg2 = 32'd0;   // set bit 0
    inst = ALU_CONTROL_BSET;
    #10;

    expected = reg1 | (32'h1 << reg2[4:0]);

     assert (out == expected) else
      $fatal("bset failed: expected %b got %b", expected, out);


    // -------- binv test --------
    reg1 = 32'b1010;
    reg2 = 32'd1;
    inst = ALU_CONTROL_BINV;
    #10;

    expected = reg1 ^ (32'h1 << reg2[4:0]);

    assert (out == expected) else
     $fatal("binv failed: expected %b got %b", expected, out);


    // -------- bext test --------
    reg1 = 32'b1010;
    reg2 = 32'd3;
    inst = ALU_CONTROL_BEXT;
    #10;

    expected = {31'b0, reg1[reg2[4:0]]};

    assert (out == expected) else
     $fatal("bext failed: expected %b got %b", expected, out);

    // -------- Edge Cases ---------

    // Bit 0 boundary
    reg1 = 32'hFFFFFFFF;
    reg2 = 32'd0;
    inst = ALU_CONTROL_BCLR; // bclr
    #10;

    expected = reg1 & ~(32'h1 << reg2[4:0]);

    assert (out == expected) else
     $fatal("corner case bit0 failed");


    // Bit 31 boundary
    reg1 = 32'hFFFFFFFF;
    reg2 = 32'd31;
    inst = ALU_CONTROL_BCLR; // bclr
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
                    0: inst = ALU_CONTROL_BCLR;
                    1: inst = ALU_CONTROL_BSET;
                    2: inst = ALU_CONTROL_BINV;
                    3: inst = ALU_CONTROL_BEXT;
                    default: inst = ALU_CONTROL_BCLR;
                endcase

                #1;

                case ( inst )

                        ALU_CONTROL_BCLR: expected = reg1 & ~(32'h1 << reg2[4:0]);

                        ALU_CONTROL_BSET: expected = reg1 | (32'h1 << reg2[4:0]);

                        ALU_CONTROL_BINV: expected = reg1 ^ (32'h1 << reg2[4:0]);

                        ALU_CONTROL_BEXT: expected = {31'b0, reg1[reg2[4:0]]};

            default: expected = 32'd0;

        endcase

        assert (out == expected) else
          $fatal("random test failed: inst=%0d reg1=%h reg2=%d expected=%h got=%h"
                , inst, reg1, reg2, expected, out);

    end

    $display("All tests passed!");

    $finish;

end

`SETUP_VCD_DUMP(zbs_tb)


endmodule
