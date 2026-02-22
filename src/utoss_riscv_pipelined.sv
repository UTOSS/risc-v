`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/id_to_ex_if.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/ex_to_if_if.svh"
`include "src/interfaces/mem_to_wb_if.svh"

// pipelined implementation of our core
module utoss_riscv_pipelined
  ( input wire clk
  , input wire reset

  // instruction memory interface begin
  , output addr_t       memory_instr__address
  , output data_t       memory_instr__write_data
  , output logic  [3:0] memory_instr__write_enable
  , input  data_t       memory_instr__read_data
  // instruction memory interface end

  // data memory interface begin
  , output addr_t       memory_data__address
  , output data_t       memory_data__write_data
  , output logic  [3:0] memory_data__write_enable
  , input  data_t       memory_data__read_data
  // data memory interface end
  );

  // common declarations begin

  if_to_id_t  if_to_id_out;
  if_to_id_t  if_to_id_reg;

  id_to_ex_t  id_to_ex_out;
  id_to_ex_t  id_to_ex_reg;

  ex_to_if_t  ex_to_if_out;
  ex_to_mem_t ex_to_mem_out;
  ex_to_mem_t ex_to_mem_reg;

  addr_t pc_target;
  logic  zero_flag;
  data_t alu_result;

  mem_to_wb_t mem_to_wb_out;
  mem_to_wb_t mem_to_wb_reg;

  data_t      wb_result;
  logic [4:0] wb_rd;
  reg [2:0] funct3;

  // common declarations end

  // fetch stage start (@thatlittlegit)

  fetch_stage u_fetch_stage
    ( .IF_to_ID ( if_to_id_out )
    , .EX_to_IF ( ex_to_if_out )

    , .clk   ( clk   )
    , .reset ( reset )

    , .imem__address ( memory_instr__address   )
    , .imem__data    ( memory_instr__read_data )
    );

  // fetch stage end

  // decode stage begin (@marwannismail)

  always_ff @ (posedge clk)
    if (reset) if_to_id_reg <= '0;
    else       if_to_id_reg <= if_to_id_out;

  Decode decode
    ( .IF_to_ID    ( if_to_id_reg               )
    , .clk         ( clk                        )
    , .reset       ( reset                      )
    , .funct3      ( funct3                     )
    , .data        ( wb_result                  )
    , .rd_wb       ( wb_rd                      )
    , .RegWriteW   ( mem_to_wb_reg.RegWriteW    )
    , .ID_to_EX    ( id_to_ex_out               )
    );

  // decode stage end

  // execute stage begin (@MSh-786 and tandr3w)

  always_ff @ (posedge clk)
    if (reset) id_to_ex_reg <= '0;
    else       id_to_ex_reg <= id_to_ex_out;

  Execute execute
    ( .ID_to_EX ( id_to_ex_reg  )
    , .clk      ( clk           )
    , .reset    ( reset         )

    , .hz_forward_a ( hz_forward_a )
    , .hz_forward_b ( hz_forward_b )

    , .wb_result      ( wb_result                )
    , .mem_alu_result ( ex_to_mem_reg.alu_result )

    , .zero_flag  ( zero_flag     )
    , .alu_result ( alu_result    )
    , .pc_target  ( pc_target     ) // TODO: Bring this into the Fetch stage
    , .EX_to_MEM  ( ex_to_mem_out )
    , .EX_to_IF   ( ex_to_if_out  )
    );

  // execute stage end

  // memory stage begin (@Invisipac)

  always_ff @ (posedge clk)
    if (reset) ex_to_mem_reg <= '0;
    else       ex_to_mem_reg <= ex_to_mem_out;

  Mem_Stage memory_stage
  ( .EX_to_MEM        ( ex_to_mem_reg )
  , .funct3           ( funct3        )
  , .dataFromMemory   (memory_data__read_data)
  , .dataToMemory     (memory_data__write_data)
  // , .MemWriteByteAddress () // TODO: Is this required?
  , .MEM_to_WB        (mem_to_wb_out)
  );

  // memory stage end

  // writeback stage begin (@TheDeepestSpace)

  always_ff @ (posedge clk)
    if (reset) mem_to_wb_reg <= '0;
    else       mem_to_wb_reg <= mem_to_wb_out;

  write_back wb
    ( .clk         ( clk   )
    , .reset       ( reset )

    , .from_memory ( mem_to_wb_reg )
    , .result      ( wb_result     )
    , .rd          ( wb_rd         )
    );

  // writeback stage end

  // hazard module begin (@DanielTaoHuang123)

  pkg_hazard_unit::forward_a_t hz_forward_a;
  pkg_hazard_unit::forward_b_t hz_forward_b;
  logic lwStall, StallF, StallD, FlushD, FlushE;

  hazard_unit u_hazard_unit
    ( .clk ( clk )

    , .Rs1E      ( id_to_ex_reg.rs1        )
    , .Rs2E      ( id_to_ex_reg.rs2        )
    , .RdM       ( ex_to_mem_reg.rd        )
    , .RdW       ( mem_to_wb_reg.rd        )
    , .RdE       ( id_to_ex_reg.rd         )
    , .RegWriteM ( ex_to_mem_reg.RegWrite  )
    , .RegWriteW ( mem_to_wb_reg.RegWriteW )
    , .PCSrcE    ( EX_to_IF.pc_src         )

    , .ForwardAE ( hz_forward_a )
    , .ForwardBE ( hz_forward_b )
    , .lwStall   ( lwStall      )
    , .StallF    ( StallF       )
    , .StallD    ( StallD       )
    , .FlushD    ( FlushD       )
    , .FlushE    ( FlushE       )
    );

  // hazard module end

endmodule
