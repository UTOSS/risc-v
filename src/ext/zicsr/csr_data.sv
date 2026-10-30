`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

module csr_data
  ( input logic clk
  , input logic reset

  /* verilator lint_off UNUSEDSIGNAL */ // only `address` is needed for the read
  , input  ext__zicsr__types::csr_request_t    csr_request
  /* verilator lint_on UNUSEDSIGNAL */
  , input  ext__zicsr__types::csr_wb_request_t csr_wb_request
  , output data_t                              csr_data

  , csr_hw_request_if.plugin mcause_hw_request
  , csr_hw_request_if.plugin mtvec_hw_request
  , csr_hw_request_if.plugin mepc_hw_request
  );

  data_t mscratch_read_value;
  data_t mhartid_read_value;
  data_t mtvec_read_value;
  data_t mepc_read_value;
  data_t mcause_read_value;

  csr_plugin_basic
    #( .NAME        ( "mscratch"         )
    , .ADDRESS      ( 12'h340            )
    , .RESET_VALUE  ( 32'h0000_0000      )
    , .WRITE_MASK   ( 32'hffff_ffff      )
    )
    u_mscratch
    ( .clk            ( clk                 )
    , .reset          ( reset               )
    , .read_address   ( csr_request.address )
    , .read_value     ( mscratch_read_value )
    , .csr_wb_request ( csr_wb_request      )
    );

  csr_plugin_basic
    #( .NAME        ( "mhartid"         )
    , .ADDRESS      ( 12'hf14           )
    , .RESET_VALUE  ( 32'h0000_0000     )
    , .WRITE_MASK   ( 32'h0000_0000     )
    )
    u_mhartid
    ( .clk            ( clk                 )
    , .reset          ( reset               )
    , .read_address   ( csr_request.address )
    , .read_value     ( mhartid_read_value  )
    , .csr_wb_request ( csr_wb_request      )
    );

  // see https://docs.riscv.org/reference/isa/v20260120/priv/machine.html#mtvec
  // only Direct mode is supported: MODE (bits 1:0) is WARL and hardwired to 0, so BASE is the whole
  // trap vector address (always 4-byte aligned)
  csr_plugin
    #( .NAME        ( "mtvec"           )
    , .ADDRESS      ( 12'h305           )
    , .RESET_VALUE  ( 32'h0000_0000     )
    , .WRITE_MASK   ( 32'hffff_fffc     )
    )
    u_mtvec
    ( .clk            ( clk                 )
    , .reset          ( reset               )
    , .read_address   ( csr_request.address )
    , .read_value     ( mtvec_read_value    )
    , .csr_hw_request ( mtvec_hw_request    )
    , .csr_wb_request ( csr_wb_request      )
    );

  csr_plugin
    #(.NAME        ( "mepc"        )
    , .ADDRESS     ( 12'h341       )
    , .RESET_VALUE ( 32'h0         )
    , .WRITE_MASK  ( 32'hffff_fffe ) // no writing to lowest bit, TODO: use assertions instead
    )
    u_mepc
      ( .clk   ( clk   )
      , .reset ( reset )

      , .read_address   ( csr_request.address )
      , .read_value     ( mepc_read_value     )

      , .csr_wb_request ( csr_wb_request  )
      , .csr_hw_request ( mepc_hw_request )
      );

  // see https://docs.riscv.org/reference/isa/v20260120/priv/machine.html#mcause
  csr_plugin
    #(.NAME        ( "mcause"                                )
    , .ADDRESS     ( 12'h342                                 )
    , .RESET_VALUE ( 32'h0                                   )
    , .WRITE_MASK  ( 32'b10000000_00000000_00000000_00011111 )
    )
    u_mcause
      ( .clk   ( clk   )
      , .reset ( reset )

      , .read_address   ( csr_request.address )
      , .read_value     ( mcause_read_value   )

      , .csr_wb_request ( csr_wb_request    )
      , .csr_hw_request ( mcause_hw_request )
      );

  // async read
  assign csr_data = mscratch_read_value
                  | mhartid_read_value
                  | mtvec_read_value
                  | mepc_read_value
                  | mcause_read_value;

endmodule
