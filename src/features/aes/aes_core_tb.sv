module aes_core_tb;

    logic clk;
    logic rst_n;

    logic start;
    logic [127:0] plaintext;
    logic [127:0] key;

    logic [127:0] ciphertext;
    logic busy;
    logic done;

    aes_core dut (
        .clk        (clk), 
        .rst_n      (rst_n), 

        .start      (start), 
        .plaintext  (plaintext), 
        .key        (key), 

        .ciphertext (ciphertext), 

        .busy       (busy), 
        .done       (done)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

//logs of every round
/*
    always @(posedge clk) begin

    if (dut.fsm_state == dut.S_ROUND) begin

        $display("ROUND %0d", dut.round);

        $display(
            "state_in  = %032h",
            dut.u_aes_round.state_in
        );

        $display(
            "shifted   = %032h",
            dut.u_aes_round.shifted_state
        );

        $display(
            "mixed     = %032h",
            dut.u_aes_round.mixed_state
        );

        $display(
            "round_key = %032h",
            dut.round_key_next
        );

        $display(
            "state_out = %032h",
            dut.state_next
        );

    end

end
*/

    task automatic run_test(
    input logic [127:0] test_plaintext, 
    input logic [127:0] test_key, 
    input logic [127:0] expected_ciphertext
    );

    begin

        // -----------------------------------------
        // Provide new inputs
        // -----------------------------------------

        plaintext = test_plaintext;
        key       = test_key;


        // -----------------------------------------
        // Issue one-cycle START pulse
        // -----------------------------------------

        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;


        // -----------------------------------------
        // Make sure this NEW operation has started
        // -----------------------------------------

        wait(busy == 1'b1);


        // -----------------------------------------
        // Wait for this operation to finish
        // -----------------------------------------

        wait(done == 1'b1);

        #1;


        // -----------------------------------------
        // Check output
        // -----------------------------------------

        if (ciphertext === expected_ciphertext) begin

            $display("PASS");
            $display("  plaintext  = %032h", test_plaintext);
            $display("  key        = %032h", test_key);
            $display("  ciphertext = %032h", ciphertext);

        end else begin

            $display("FAIL");
            $display("  plaintext  = %032h", test_plaintext);
            $display("  key        = %032h", test_key);
            $display("  expected   = %032h", expected_ciphertext);
            $display("  actual     = %032h", ciphertext);

            $fatal;

        end

    end

    endtask


    initial begin

        clk       = 1'b0;
        rst_n     = 1'b0;
        start     = 1'b0;

        plaintext = 128'b0;
        key       = 128'b0;


        // -----------------------------------------
        // Reset
        // -----------------------------------------

        repeat (2)
            @(posedge clk);

        rst_n = 1'b1;


        // =========================================
        // FIPS 197 Appendix B
        // =========================================

        run_test(
            128'h3243f6a8885a308d313198a2e0370734, 
            128'h2b7e151628aed2a6abf7158809cf4f3c, 
            128'h3925841d02dc09fbdc118597196a0b32
        );


        // =========================================
        // NIST SP 800-38A AES-128
        // =========================================
        
        run_test(
            128'h6bc1bee22e409f96e93d7e117393172a, 
            128'h2b7e151628aed2a6abf7158809cf4f3c, 
            128'h3ad77bb40d7a3660a89ecaf32466ef97
        );

        run_test(
            128'hae2d8a571e03ac9c9eb76fac45af8e51, 
            128'h2b7e151628aed2a6abf7158809cf4f3c, 
            128'hf5d3d58503b9699de785895a96fdbaaf
        );

        run_test(
            128'h30c81c46a35ce411e5fbc1191a0a52ef, 
            128'h2b7e151628aed2a6abf7158809cf4f3c, 
            128'h43b1cd7f598ece23881b00e3ed030688
        );

        run_test(
            128'hf69f2445df4f9b17ad2b417be66c3710, 
            128'h2b7e151628aed2a6abf7158809cf4f3c, 
            128'h7b0c785e27e8ad3f8223207104725dd4
        );


        $display("=================================");
        $display("ALL AES TESTS PASSED");
        $display("=================================");

        $finish;

    end

endmodule
