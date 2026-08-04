`include "src/timescale.svh"

`include "test/utils.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module fetch_rvc_14_split_at_pc_06_tb;

reg clk;
reg reset;
reg stall_f;
reg flush_f;

if_to_id_t if_to_id;

wire unused_if_to_id_pc_plus_4 =
  &{1'b0, if_to_id.pc_plus_4};

ex_to_if_t ex_to_if;

addr_t imem__address;
logic [7:0] imem_word_index;
wire unused_imem_address =
&{1'b0, imem__address[31:10], imem__address[1:0]};

assign imem_word_index = imem__address[9:2];

data_t imem__data;

data_t imem [0:255];

localparam instr_t NOP = 32'h00000013;

fetch_stage uut
( .if_to_id      ( if_to_id      )
, .ex_to_if      ( ex_to_if      )
, .clk           ( clk           )
, .reset         ( reset         )
, .stall_f       ( stall_f       )
, .flush_f       ( flush_f       )
, .imem__address ( imem__address )
, .imem__data    ( imem__data    )
);

initial begin
clk = 0;
forever #5 clk = ~clk;
end

// Synchronous instruction memory model: imem__data returns the word
// requested by imem__address on the previous rising edge.
always @ (posedge clk) begin
imem__data <= imem[imem_word_index];
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
for (n = 0; n < 3; n = n + 1) begin
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

    if (!seen)
      tick();
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

initial begin
init_common();

imem[0] = 32'h00010001; // PC 0x00: C.NOP, PC 0x02: C.NOP
imem[1] = 32'h00930001; // PC 0x04: C.NOP, PC 0x06: low half split
imem[2] = 32'h000100A0; // PC 0x08: high half split, PC 0x0A: C.NOP

release_reset();

wait_fetch(32'h00000000, NOP,          "C.NOP PC 0x00");
wait_fetch(32'h00000002, NOP,          "C.NOP PC 0x02");
wait_fetch(32'h00000004, NOP,          "C.NOP before split at PC 0x06");
wait_fetch(32'h00000006, NOP,          "bubble for split at PC 0x06");
wait_fetch(32'h00000006, 32'h00A00093, "real split ADDI at PC 0x06");
wait_fetch(32'h0000000A, NOP,          "C.NOP after split at PC 0x0A");

$finish;


end

`SETUP_VCD_DUMP(fetch_rvc_14_split_at_pc_06_tb)

endmodule
