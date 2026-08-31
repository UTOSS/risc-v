module aes_core (
  input  logic         clk
, input  logic         rst_n
// Command
, input  logic         start
// AES-128 input
, input  logic [127:0] plaintext
, input  logic [127:0] key
// AES-128 output
, output logic [127:0] ciphertext
// Status
, output logic         busy
, output logic         done
);

    // FSM states
    typedef enum logic [2:0] {
      S_IDLE
    , S_INIT
    , S_ROUND
    , S_FINAL
    , S_DONE
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
        .key_in  (round_key_reg)
      , .round   (round)
      , .key_out (round_key_next)
    );


    // AES round datapath
    // use round_key_next

    aes_round u_aes_round (
    .state_in    (state_reg)
    , .round_key   (round_key_next)
    , .final_round (final_round)
    , .state_out   (state_next)
    );

// AES controller FSM
// split into separate always_ff blocks for svlint
// FSM state
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        fsm_state <= S_IDLE;
    else
        case (fsm_state)

            S_IDLE:
                if (start)
                    fsm_state <= S_INIT;

            S_INIT:
                fsm_state <= S_ROUND;

            S_ROUND:
                if (round == 4'd9)
                    fsm_state <= S_FINAL;

            S_FINAL:
                fsm_state <= S_DONE;

            S_DONE:
                if (start)
                    fsm_state <= S_INIT;

            default:
                fsm_state <= S_IDLE;

        endcase


// Input reg
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        plaintext_reg <= 128'b0;
    else if ((fsm_state == S_IDLE || fsm_state == S_DONE) && start)
        plaintext_reg <= plaintext;


always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        key_reg <= 128'b0;
    else if ((fsm_state == S_IDLE || fsm_state == S_DONE) && start)
        key_reg <= key;



// AES state reg
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        state_reg <= 128'b0;
    else
        case (fsm_state)

            S_INIT:
                state_reg <= plaintext_reg ^ key_reg;

            S_ROUND:
                state_reg <= state_next;

            S_FINAL:
                state_reg <= state_next;

            default:
                state_reg <= state_reg;

        endcase



// Round key reg
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        round_key_reg <= 128'b0;
    else
        case (fsm_state)

            S_INIT:
                round_key_reg <= key_reg;

            S_ROUND:
                round_key_reg <= round_key_next;

            S_FINAL:
                round_key_reg <= round_key_next;

            default:
                round_key_reg <= round_key_reg;

        endcase


// Round counter
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        round <= 4'b0;
    else
        case (fsm_state)

            S_INIT:
                round <= 4'd1;

            S_ROUND:
                if (round == 4'd9)
                    round <= 4'd10;
                else
                    round <= round + 1'b1;

            default:
                round <= round;

        endcase

// Ciphertext reg
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        ciphertext <= 128'b0;
    else if (fsm_state == S_FINAL)
        ciphertext <= state_next;

// Busy
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        busy <= 1'b0;
    else
        case (fsm_state)

            S_IDLE:
                if (start)
                    busy <= 1'b1;
                else
                    busy <= 1'b0;

            S_FINAL:
                busy <= 1'b0;

            S_DONE:
                if (start)
                    busy <= 1'b1;
                else
                    busy <= 1'b0;

            default:
                busy <= busy;

        endcase


// Done
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        done <= 1'b0;
    else
        case (fsm_state)

            S_IDLE:
                done <= 1'b0;

            S_FINAL:
                done <= 1'b1;

            S_DONE:
                if (start)
                    done <= 1'b0;
                else
                    done <= 1'b1;

            default:
                done <= done;

        endcase

endmodule
