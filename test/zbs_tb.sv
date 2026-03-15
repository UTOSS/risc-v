`timescale 1ns/1ns
`include "test/utils.svh"

module zbs_tb;

logic [31:0] reg1;
logic [31:0] reg2;
logic [2:0]  inst;
logic [31:0] out;

logic [31:0] expected;

zbs uut (
    .reg1(reg1),
    .reg2(reg2),
    .inst(inst),
    .out(out)
);

initial begin

    // -------- bclr test --------
    reg1 = 32'b1010;
    reg2 = 32'd1;   // clear bit 1
    inst = 3'b000;
    #10;

    expected = reg1 & ~(32'h1 << reg2[4:0]);

    assert(out == expected)
        else $fatal("bclr failed: expected %b got %b", expected, out);


    // -------- bset test --------
    reg1 = 32'b1110;
    reg2 = 32'd0;   // set bit 0
    inst = 3'b001;
    #10;

    expected = reg1 | (32'h1 << reg2[4:0]);

    assert(out == expected)
        else $fatal("bset failed: expected %b got %b", expected, out);


    // -------- binv test --------
    reg1 = 32'b1010;
    reg2 = 32'd1;
    inst = 3'b010;
    #10;

    expected = reg1 ^ (32'h1 << reg2[4:0]);

    assert(out == expected)
        else $fatal("binv failed: expected %b got %b", expected, out);


    // -------- bext test --------
    reg1 = 32'b1010;
    reg2 = 32'd3;
    inst = 3'b011;
    #10;

    expected = (reg1 >> reg2[4:0]) & 32'h1;

    assert(out == expected)
        else $fatal("bext failed: expected %b got %b", expected, out);

    // -------- Edge Cases ---------

    // Bit 0 boundary
    reg1 = 32'hFFFFFFFF;
    reg2 = 32'd0;
    inst = 3'b000; // bclr
    #10;

    expected = reg1 & ~(32'h1 << reg2[4:0]);

    assert(out == expected)
        else $fatal("corner case bit0 failed");


    // Bit 31 boundary
    reg1 = 32'hFFFFFFFF;
    reg2 = 32'd31;
    inst = 3'b000; // bclr
    #10;

    expected = reg1 & ~(32'h1 << reg2[4:0]);

    assert(out == expected)
        else $fatal("corner case bit31 failed");


    // ----------- Randomized Testing (Experimental) -----------
 

    repeat (1000) begin

        reg1 = $urandom;
        reg2 = $urandom % 32;
        inst = $urandom % 4;

        #1;

        case(inst)

            3'b000: expected = reg1 & ~(32'h1 << reg2[4:0]);

            3'b001: expected = reg1 | (32'h1 << reg2[4:0]);

            3'b010: expected = reg1 ^ (32'h1 << reg2[4:0]);

            3'b011: expected = (reg1 >> reg2[4:0]) & 32'h1;

            default: expected = 32'd0;

        endcase

        assert(out == expected)
            else $fatal("random test failed: inst=%0d reg1=%h reg2=%d expected=%h got=%h",
                        inst, reg1, reg2, expected, out);

    end

    $display("All tests passed!");

    $finish;

end

`SETUP_VCD_DUMP(zbs_tb)

endmodule