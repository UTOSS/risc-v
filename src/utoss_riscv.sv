`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/id_to_ex_if.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/ex_to_if_if.svh"
`include "src/interfaces/mem_to_wb_if.svh"
`include "src/interfaces/MEM_BUS.svh"

// make a new include 

// interface instr_bus (input clk);
//   addr_t memory_instr__address; // out
//   data_t       memory_instr__write_data; // out
//   logic  [3:0] memory_instr__write_enable; // out
//   data_t       memory_instr__read_data; // in
// endinterface 

// interface data_mem_bus;
//   addr_t       memory_data__address; // out
//   data_t       memory_data__write_data; // out
//   logic  [3:0] memory_data__write_enable; // out
//   data_t       memory_data__read_data; // in
// endinterface

// do i putmy name here? (@Nugget-exe)

// interface mem_bus //(input clk); // because some are clocked(or not ig)

//   // //instruction 
//   // addr_t       memory_instr__address; // out
//   // data_t       memory_instr__write_data; // out
//   // logic  [3:0] memory_instr__write_enable; // out
//   // data_t       memory_instr__read_data; // in

//   // //data
//   // addr_t       memory_data__address; // out
//   // data_t       memory_data__write_data; // out
//   // logic  [3:0] memory_data__write_enable; // out
//   // data_t       memory_data__read_data; // in

//   addr_t       memory__address; // out
//   data_t       memory__write_data; // out
//   logic  [3:0] memory__write_enable; // out
//   data_t       memory__read_data; // in


//   // modport instr_bus(
//   //   input memory_instr__read_data,
//   //   output memory_instr__address,
//   //   output memory_instr__write_data,
//   //   output memory_instr__write_enable
//   // );

//   // modport data_mem_bus(
//   //   input memory_data__read_data,
//   //   output memory_data__address,
//   //   output memory_data__write_data,
//   //   output memory_data__write_enable
//   // );

//   modport memory(
//     input memory__read_data,
//     output memory__address, // out
//     output memory__write_data, // out
//     output memory__write_enable // out
//   ); 

//   modport consumer(
//     input memory__read_data,
//     output memory__address, // out
//     output memory__write_data, // out
//     output memory__write_enable // out
//   ); 



// endinterface 


// pipelined implementation of our core
module utoss_riscv
  ( input wire clk
  , input wire reset
  , MEM_BUS.consumer i_bus
  , MEM_BUS.consumer d_bus

  // instruction memory interface begin

  // change to sv interface
  );

  // common declarations begin

  if_to_id_t  if_to_id_out;
  if_to_id_t  if_to_id_reg;

  id_to_ex_t  id_to_ex_out;
  id_to_ex_t  id_to_ex_reg;

  ex_to_if_t  ex_to_if_out;
  ex_to_mem_t ex_to_mem_out;
  ex_to_mem_t ex_to_mem_reg;

  mem_to_wb_t mem_to_wb_out;
  mem_to_wb_t mem_to_wb_reg;

  data_t      wb_result;
  logic [4:0] wb_rd;



  // common declarations end

  // fetch stage start (@thatlittlegit)

  fetch_stage u_fetch_stage
    ( .if_to_id ( if_to_id_out )
    , .ex_to_if ( ex_to_if_out )

    , .clk     ( clk    )
    , .reset   ( reset  )
    , .stall_f ( stall_f )
    , .flush_f ( flush_f )

    , .imem__address (i_bus.memory__address)//( memory_instr__address   )
    , .imem__data    (i_bus.memory__read_data)//( memory_instr__read_data )
    );


  assign i_bus.mem_write_data = data_t'(0); 
  assign i_bus.mem_write_enable = 4'b0;


  

  // fetch stage end
  // interface end @bugget

  // decode stage begin (@marwannismail)

  always_ff @ (posedge clk)
    if (reset)         if_to_id_reg <= '0;
    else if (flush_d)  if_to_id_reg <= '0;
    else if (!stall_d) if_to_id_reg <= if_to_id_out;

  wire [4:0] id_rs1, id_rs2;

  decode_stage u_decode_stage
    ( .if_to_id ( if_to_id_reg )

    , .clk         ( clk                     )
    , .reset       ( reset                   )
    , .data        ( wb_result               )
    , .rd_wb       ( wb_rd                   )
    , .reg_write_w ( mem_to_wb_reg.reg_write )

    , .rs1 ( id_rs1 )
    , .rs2 ( id_rs2 )

    , .id_to_ex ( id_to_ex_out )
    );

  // decode stage end

  // execute stage begin (@MSh-786 and tandr3w)

  always_ff @ (posedge clk)
    if (reset)        id_to_ex_reg <= '0;
    else if (flush_e) id_to_ex_reg <= '0;
    else              id_to_ex_reg <= id_to_ex_out;

  execute_stage u_execute_stage
    ( .id_to_ex ( id_to_ex_reg )

    , .hz_forward_a ( hz_forward_a )
    , .hz_forward_b ( hz_forward_b )

    , .wb_result      ( wb_result                )
    , .mem_alu_result ( ex_to_mem_reg.alu_result )

    , .ex_to_mem ( ex_to_mem_out )
    , .ex_to_if  ( ex_to_if_out  )
    );

  // execute stage end

  // memory stage begin (@Invisipac)

  always_ff @ (posedge clk)
    if (reset) ex_to_mem_reg <= '0;
    else       ex_to_mem_reg <= ex_to_mem_out;

  memory_stage u_memory_stage
  ( .ex_to_mem ( ex_to_mem_reg )

  // change to use interface(Bugget)

  , .mem_write_data   (d_bus.memory__write_data)//( memory_data__write_data   )
  , .mem_write_enable (d_bus.memory__write_enable)//( memory_data__write_enable ) // TODO: Is this required?
  , .mem_address      (d_bus.memory__address)//( memory_data__address      )

  , .mem_to_wb ( mem_to_wb_out)
  );

  // memory stage end

  // writeback stage begin (@TheDeepestSpace)

  always_ff @ (posedge clk)
    if (reset) mem_to_wb_reg <= '0;
    else       mem_to_wb_reg <= mem_to_wb_out;

  write_back_stage u_write_back_stage
    ( .from_memory ( mem_to_wb_reg )
    , .ex_to_mem   ( ex_to_mem_reg )
    // change to use interface Bugget
    , .data_from_memory (d_bus.memory__read_data)//( memory_data__read_data )
    , .result           ( wb_result              )
    , .rd               ( wb_rd                  )
    );

  // writeback stage end

  // hazard module begin (@DanielTaoHuang123)

  hazard_forward_a_t hz_forward_a;
  hazard_forward_b_t hz_forward_b;
  logic stall_f, stall_d, flush_f, flush_d, flush_e;

  hazard_unit u_hazard_unit
    ( .clk ( clk )

    , .rs1_d        ( id_rs1                  )
    , .rs2_d        ( id_rs2                  )
    , .rs1_e        ( id_to_ex_reg.rs1        )
    , .rs2_e        ( id_to_ex_reg.rs2        )
    , .rd_m         ( ex_to_mem_reg.rd        )
    , .rd_w         ( mem_to_wb_reg.rd        )
    , .rd_e         ( id_to_ex_reg.rd         )
    , .reg_write_m  ( ex_to_mem_reg.reg_write )
    , .reg_write_w  ( mem_to_wb_reg.reg_write )
    , .result_src_e ( id_to_ex_reg.result_src )
    , .pc_src_e     ( ex_to_if_out.pc_src     )

    , .forward_a_e ( hz_forward_a )
    , .forward_b_e ( hz_forward_b )
    , .stall_f    ( stall_f       )
    , .stall_d    ( stall_d       )
    , .flush_f    ( flush_f       )
    , .flush_d    ( flush_d       )
    , .flush_e    ( flush_e       )
    );

  // hazard module end

`ifdef UTOSS_PIPELINE_LOGGER
  Logger u_logger
    ( .clk   ( clk   )
    , .reset ( reset )

    , .if_stage      ( if_to_id_out  )
    , .id_stage      ( if_to_id_reg  )
    , .ex_stage      ( id_to_ex_reg  )
    , .ex_stage_out  ( ex_to_mem_out )
    , .ex_to_if      ( ex_to_if_out  )
    , .mem_stage     ( ex_to_mem_reg )
    , .mem_stage_out ( mem_to_wb_out )
    , .wb_stage      ( mem_to_wb_reg )

    // change to use interface Bugget
    , .imem_address      (i_bus.memory__address)//( memory_instr__address     )
    , .dmem_address      (d_bus.memory__address)//( memory_data__address      )
    , .dmem_read_data    (d_bus.memory__read_data)//( memory_data__read_data    )
    , .dmem_write_data   (d_bus.memory__write_data)//( memory_data__write_data   )
    , .dmem_write_enable (d_bus.memory__write_enable)//( memory_data__write_enable )

    , .wb_result ( wb_result )
    , .wb_rd     ( wb_rd     )

    , .stall_f ( stall_f )
    , .stall_d ( stall_d )
    , .flush_f ( flush_f )
    , .flush_d ( flush_d )
    , .flush_e ( flush_e )
    );
`endif


endmodule
