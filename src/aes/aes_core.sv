module aes_core (
    input  logic         clk,
    input  logic         rst_n,
    // Command
    input  logic         start,
    // AES-128 input
    input  logic [127:0] plaintext,
    input  logic [127:0] key,
    // AES-128 output
    output logic [127:0] ciphertext,
    // Status
    output logic         busy,
    output logic         done
);

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE,
        S_INIT,
        S_ROUND,
        S_FINAL,
        S_DONE
    } aes_state_t;

    aes_state_t fsm_state;

    // Input registers
    logic [127:0] plaintext_reg;
    logic [127:0] key_reg;

    // AES working registers
    logic [127:0] state_reg;
    logic [127:0] round_key_reg;

    logic [3:0] round;

    // Combinational datapath signals
    logic [127:0] state_next;
    logic [127:0] round_key_next;

    logic final_round;

    // Final-round control
    // AES round 10 skips MixColumns.
    assign final_round = (fsm_state == S_FINAL);

    aes_key_schedule u_aes_key_schedule (
        .key_in  (round_key_reg),
        .round   (round),
        .key_out (round_key_next)
    );


    // AES round datapath
    // use round_key_next

    aes_round u_aes_round (
        .state_in    (state_reg),
        .round_key   (round_key_next),
        .final_round (final_round),
        .state_out   (state_next)
    );

    // AES controller FSM
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            fsm_state <= S_IDLE;

            plaintext_reg <= 128'b0;
            key_reg       <= 128'b0;

            state_reg     <= 128'b0;
            round_key_reg <= 128'b0;

            ciphertext <= 128'b0;

            round <= 4'b0;

            busy <= 1'b0;
            done <= 1'b0;

        end else begin

            case (fsm_state)

                S_IDLE: begin

                    busy <= 1'b0;
                    done <= 1'b0;

                    if (start) begin
                        // Preserve input values.
                        plaintext_reg <= plaintext;
                        key_reg       <= key;

                        busy <= 1'b1;

                        fsm_state <= S_INIT;

                    end

                end



                // INIT
                // AES initial AddRoundKey:
                // K0 is the original AES key.

                S_INIT: begin

                    state_reg     <= plaintext_reg ^ key_reg;
                    round_key_reg <= key_reg;

                    // Next operation will be AES round 1
                    round <= 4'd1;

                    fsm_state <= S_ROUND;

                end


                // ROUND
                // Perform AES rounds 1 through 9
                S_ROUND: begin

                    state_reg     <= state_next;
                    round_key_reg <= round_key_next;

                    if (round == 4'd9) begin

                        round <= 4'd10;

                        fsm_state <= S_FINAL;

                    end else begin

                        round <= round + 1'b1;

                    end

                end

                // FINAL
                // Perform AES round 10
                S_FINAL: begin

                    state_reg     <= state_next;
                    round_key_reg <= round_key_next;

                    // Capture final ciphertext
                    ciphertext <= state_next;

                    busy <= 1'b0;
                    done <= 1'b1;

                    fsm_state <= S_DONE;

                end

                // DONE
                // Keep ciphertext and done valid until another AES operation is requested

                S_DONE: begin

                    busy <= 1'b0;
                    done <= 1'b1;

                    if (start) begin

                        // Capture the next operation's inputs
                        plaintext_reg <= plaintext;
                        key_reg       <= key;

                        done <= 1'b0;
                        busy <= 1'b1;

                        fsm_state <= S_INIT;

                    end

                end

                default: begin

                    fsm_state <= S_IDLE;

                    busy <= 1'b0;
                    done <= 1'b0;

                end

            endcase

        end

    end

endmodule