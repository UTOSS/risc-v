/* module for fetching instructions
 *
 * concerns itself with reading instruction from the instruction memory, as well as managing the
 * program counter (PC); implemented as a Moore FSM
 */

`include "src/utils.svh"
`include "src/types.svh"

module fetch ( input  wire     clk
             , input  wire     reset
             , input  wire     cfsm__pc_update
             , input  pc_src_t cfsm__pc_src
             , input  imm_t    imm_ext
             , output instr_t  instr
             );

  typedef enum logic [2:0] {
    FETCH_INSTRUCTION,
    IDLE,
    INCREMENT_PC,
    JUMP_PC
  } state_t;

  state_t cur_state, next_state;

  addr_t pc_cur;
  addr_t saved_imm_reg;

  always @ (*) begin
    case (cur_state)
      FETCH_INSTRUCTION, IDLE: begin
        if (cfsm__pc_update) begin
          case (cfsm__pc_src)
            PC_SRC__INCREMENT: next_state = INCREMENT_PC;
            PC_SRC__JUMP:      next_state = JUMP_PC;
          endcase
        end else begin
          next_state = IDLE;
        end
      end
      INCREMENT_PC: next_state = FETCH_INSTRUCTION;
      JUMP_PC:      next_state = FETCH_INSTRUCTION;
      default:      next_state = FETCH_INSTRUCTION;
    endcase
  end

  always @ (posedge clk) begin
    if (reset) begin
      cur_state <= FETCH_INSTRUCTION;
      pc_cur    <= 32'h00000000;
    end else begin
      cur_state <= next_state;
    end

    saved_imm_reg <= imm_ext;
  end

  always @ (*) begin
    case (cur_state)
      FETCH_INSTRUCTION: pc_cur = pc_cur;
      IDLE:              pc_cur = pc_cur;
      INCREMENT_PC:      pc_cur = pc_cur + 32'h4;
      JUMP_PC:           pc_cur = pc_cur + saved_imm_reg;
      default:           pc_cur = 32'hxxxxxxxx;
    endcase
  end

  MA instruction_memory
    ( .A   ( pc_cur       )
    , .WD  ( 32'hxxxxxxxx )
    , .WE  ( `FALSE       )
    , .CLK ( clk          )
    , .RD  ( instr        )
    );

endmodule
