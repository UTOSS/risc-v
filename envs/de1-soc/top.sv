//do i need include? 

`include "src/interfaces/mem_bus.svh"

module top
  ( input  wire       CLOCK_50
  , input  wire [3:0] KEY
  , output wire [9:0] LEDR
  );

  // addr_t       memory_data__address;
  // data_t       memory_data__write;
  // logic  [3:0] memory_data__write_enable;
  // data_t       memory_data__read;

  // addr_t       memory_instr__address;
  // data_t       memory_instr__write;
  // logic  [3:0] memory_instr__write_enable;
  // data_t       memory_instr__read;

  // declare interface

  // MEM_BUS.memory i_bus;
  // MEM_BUS.memory d_bus;

  MEM_BUS i_bus();
  Mem_BUS d_bus();

  memory_map #( .SIZE ( 512 ) )
    memory_map
      ( .clk ( CLOCK_50 )

      // , .data__address      ( memory_data__address      )
      // , .data__write        ( memory_data__write        )
      // , .data__write_enable ( memory_data__write_enable )
      // , .data__read         ( memory_data__read         )

      , .data__address (d_bus.memory__address)
      , .data__write (d_bus.memory__write_data)
      , .data__write_enable (d_bus.memory__write_enable)
      , .data__read (d_bus.memory__read_data)

      // , .instr__address     ( memory_instr__address     )
      // , .instr__read        ( memory_instr__read        )

      , .instr__address (i_bus.memory__address)
      , .instr__read (i_bus.memory__read_data)

      , .LEDR ( LEDR )
      );

  utoss_riscv core
    ( .clk   ( CLOCK_50 )
    , .reset ( ~KEY[0]   )

    // , .memory_data__address      ( memory_data__address      )
    // , .memory_data__write_data   ( memory_data__write        )
    // , .memory_data__write_enable ( memory_data__write_enable )
    // , .memory_data__read_data    ( memory_data__read         )

    // , .memory_instr__address      ( memory_instr__address      )
    // , .memory_instr__write_data   ( memory_instr__write        )
    // , .memory_instr__write_enable ( memory_instr__write_enable )
    // , .memory_instr__read_data    ( memory_instr__read         )
    , .d_bus(d_bus)
    , .i_bus(i_bus)
    // , .memory_data__address      (d_bus.memory__address)//( memory__address      )
    // , .memory_data__write_data   (d_bus.memory__write_data)//( memory__write_data   )
    // , .memory_data__write_enable (d_bus.memory__write_enable)//( memory__write_enable )
    // , .memory_data__read_data    (d_bus.memory__read_data)//( memory__read_data    )

    // , .memory_instr__address      (i_bus.memory__address)//( imem__address        )
    // , .memory_instr__write_data   (i_bus.memory__write_data)//( imem__write_data     )
    // , .memory_instr__write_enable (i_bus.memory__write_enable)//( imem__write_enable   )
    // , .memory_instr__read_data    (i_bus.memory__read_data)//( imem__read_data      )
    );

endmodule
