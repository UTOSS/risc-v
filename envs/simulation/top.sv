`include "src/headers/types.svh"
`include "src/interfaces/mem_bus.svh"

module top
  #( parameter MEM_SIZE = 1024 ) //maybe change to 2048 if using dual port?
  ( input wire clk
  , input wire reset
  // , MEM_BUS.memory i_bus   
  // , MEM_BUS.memory d_bus
  );

  // addr_t       memory__address;
  // data_t       memory__write_data;
  // logic  [3:0] memory__write_enable;
  // data_t       memory__read_data;

  // addr_t       imem__address;
  // data_t       imem__read_data;

  // data_t       imem__write_data;
  // logic [3:0]  imem__write_enable;
  MEM_BUS i_bus();
  MEM_BUS d_bus();


  wire unused = &{i_bus.memory__write_data, i_bus.memory__write_enable}; //&{imem__write_data, imem__write_enable};

  memory #( .SIZE ( MEM_SIZE ) )

  // u could prob do the same from the core thingy here @Bugget
    u_memory
      ( .clk                      ( clk                  )
      , .address                  (d_bus.memory__address)//( memory__address      )
      , .instruction_address      (i_bus.memory__address)//( imem__address        )
      , .write_data               (d_bus.memory__write_data)//( memory__write_data   )
      , .write_enable             (d_bus.memory__write_enable)//( memory__write_enable )
      , .read_data                (d_bus.memory__read_data)//( memory__read_data    )
      , .instruction_read_data    (i_bus.memory__read_data)//( imem__read_data      )
      );

  utoss_riscv core
    ( .clk    ( clk    )
    , .reset  ( reset  )

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
