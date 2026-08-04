`include "src/timescale.svh"

`include "test/utils.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module fetch_rvc_11_stall_while_buffer_valid_tb;

  reg clk;
  reg reset;
  reg stall_f;
  reg flush_f;

  if_to_id_t if_to_id;
  ex_to_if_t ex_to_if;

  addr_t imem__address;
  data_t imem__data;

  data_t imem [0:255];

  localparam instr_t NOP = 32'h00000013;
  localparam bit [15:0] C_NOP = 16'h0001;

  wire unused_imem_address =
    &{1'b0, imem__address[31:10], imem__address[1:0]};

  fetch_stage uut
    ( .if_to_id      (if_to_id)
    , .ex_to_if      (ex_to_if)
    , .clk           (clk)
    , .reset         (reset)
    , .stall_f       (stall_f)
    , .flush_f       (flush_f)
    , .imem__address (imem__address)
    , .imem__data    (imem__data)
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  always @ (posedge clk) begin
    imem__data <= imem[imem__address[9:2]];
  end

  task tick;
    @(posedge clk); #1;
  endtask

  task init_common;
    integer i;
    begin
      reset  = `TRUE;
      stall_f = 1'b0;
      flush_f = 1'b0;

      ex_to_if.pc_src    = PC_SRC__INCREMENT;
      ex_to_if.pc_target = addr_t'(0);
      ex_to_if.pc_old    = addr_t'(0);
      ex_to_if.imm_ext   = data_t'(0);

      imem__data = data_t'(0);

      for (i = 0; i < 256; i = i + 1) begin
        imem[i] = NOP;
      end
    end
  endtask

  task release_reset;
    begin
      repeat (3) tick();
      reset = `FALSE;
    end
  endtask

  task wait_fetch;
    input addr_t  exp_pc;
    input instr_t exp_instr;
    input [8 * 80 - 1:0] label;
    integer n;
    reg seen;
    begin
      seen = 1'b0;

      for (n = 0; n < 40; n = n + 1) begin
        if (!stall_f && !flush_f &&
            if_to_id.pc_cur === exp_pc &&
            if_to_id.instruction === exp_instr) begin
          $display
            ( "[pass] %0s pc=0x%08h instr=0x%08h"
            , label
            , if_to_id.pc_cur
            , if_to_id.instruction
            );
          seen = 1'b1;
          n = 40;
        end
        else begin
          tick();
        end
      end

      if (!seen) begin
        $display
          ( "[fail] %0s expected pc=0x%08h instr=0x%08h, got pc=0x%08h instr=0x%08h"
          , label
          , exp_pc
          , exp_instr
          , if_to_id.pc_cur
          , if_to_id.instruction
          );
        $fatal(1);
      end
    end
  endtask

  task wait_buffer_valid;
    input [8 * 80 - 1:0] label;
    integer n;
    reg seen;
    begin
      seen = 1'b0;

      for (n = 0; n < 3; n = n + 1) begin
        if (uut.fetch_compressed_i.buffered_word_valid === 1'b1) begin
          $display
            ( "[pass] %0s"
            , label
            );
          seen = 1'b1;
          n = 3;
        end
        else begin
          tick();
        end
      end

      if (!seen) begin
        $display
          ( "[fail] %0s buffered_word_valid never became 1"
          , label
          );
        $fatal(1);
      end
    end
  endtask

  initial begin
    init_common();

    imem[0] = {C_NOP, C_NOP};
    imem[1] = NOP;

    release_reset();

    wait_fetch
      ( 32'h00000000
      , NOP
      , "lower C.NOP creates same-word buffer"
      );

    wait_buffer_valid
      ( "same-word buffer becomes valid before stall"
      );

    stall_f = 1'b1;

    repeat (3) begin
      tick();
      `assert_equal(uut.fetch_compressed_i.buffered_word_valid, 1'b1)
    end

    stall_f = 1'b0;
    #1;

    `assert_equal(if_to_id.pc_cur, 32'h00000002)
    `assert_equal(if_to_id.instruction, NOP)
    `assert_equal(if_to_id.pc_plus_4, 32'h00000004)

    tick();

    `assert_equal(uut.fetch_compressed_i.buffered_word_valid, 1'b0)

    $finish;
  end

  `SETUP_VCD_DUMP(fetch_rvc_11_stall_while_buffer_valid_tb)

endmodule
