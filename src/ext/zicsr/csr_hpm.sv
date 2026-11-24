`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zicsr/types.svh"

// Machine-mode hardware performance monitor: mcycle, minstret and mhpmcounter3-31, plus the
// mhpmevent3-31 selectors that choose the event each counter counts.
//
// mcycle counts clock cycles and minstret counts retired instructions; both always count, as the
// spec requires. mhpmcounterN counts the event selected by mhpmeventN:
//
//   0 - nothing, the counter stays stopped
//   1 - clock cycles
//   2 - retired instructions
//
// Reserved event encodings and the reserved bits of mhpmeventN read back as written, but select no
// event. Each counter is 64-bit wide and is accessed through its low (0xb0N) and high (0xb8N)
// halves, following the RV32 layout of the machine counters.
module csr_hpm
  ( input logic clk
  , input logic reset
  , input logic retire // an instruction left ID for EX in the previous cycle, i.e. it retired

  , input  csr_addr_t                          read_address
  , output data_t                              read_value

  , input  ext__zicsr__types::csr_wb_request_t csr_wb_request
  );

  import ext__zicsr__types::*;

  typedef enum logic [1:0]
    { HPM_EVENT__NONE    = 2'd0
    , HPM_EVENT__CYCLE   = 2'd1
    , HPM_EVENT__INSTRET = 2'd2
    } hpm_event_t;

  localparam int HPM_COUNTER_FIRST = 3;
  localparam int HPM_COUNTER_LAST  = 31;

  data_t mcycle_read_value;
  data_t minstret_read_value;
  data_t hpm_read_value [HPM_COUNTER_FIRST:HPM_COUNTER_LAST];

  csr_hpm_counter
    #( .ADDRESS_LOW  ( 12'hb00 )
    , .ADDRESS_HIGH ( 12'hb80 )
    )
    u_mcycle
    ( .clk            ( clk               )
    , .reset          ( reset             )
    , .increment      ( 1'b1              )
    , .read_address   ( read_address      )
    , .read_value     ( mcycle_read_value )
    , .csr_wb_request ( csr_wb_request    )
    );

  csr_hpm_counter
    #( .ADDRESS_LOW  ( 12'hb02 )
    , .ADDRESS_HIGH ( 12'hb82 )
    )
    u_minstret
    ( .clk            ( clk                 )
    , .reset          ( reset               )
    , .increment      ( retire              )
    , .read_address   ( read_address        )
    , .read_value     ( minstret_read_value )
    , .csr_wb_request ( csr_wb_request      )
    );

  generate
    for (genvar i = HPM_COUNTER_FIRST; i <= HPM_COUNTER_LAST; i++) begin: l_hpm_counter
      localparam bit [11:0] COUNTER_ADDRESS_LOW  = 12'hb00 + 12'(i);
      localparam bit [11:0] COUNTER_ADDRESS_HIGH = 12'hb80 + 12'(i);
      localparam bit [11:0] EVENT_ADDRESS        = 12'h320 + 12'(i);

      data_t      event_selector;
      hpm_event_t selected_event;
      logic       increment;
      data_t      counter_read_value;

      // mhpmeventN: only two bits select an event today, the rest is reserved
      always_ff @(posedge clk)
        if (reset)
          event_selector <= '0;
        else if (csr_wb_request.write_enable && (csr_wb_request.address == csr_addr_t'(EVENT_ADDRESS)))
          event_selector <= csr_wb_request.data;

      assign selected_event = hpm_event_t'(event_selector[1:0]);
      assign increment      = (selected_event == HPM_EVENT__CYCLE)   ? 1'b1
                            : (selected_event == HPM_EVENT__INSTRET) ? retire
                            :                                          1'b0;

      csr_hpm_counter
        #( .ADDRESS_LOW  ( COUNTER_ADDRESS_LOW  )
        , .ADDRESS_HIGH ( COUNTER_ADDRESS_HIGH )
        )
        u_counter
        ( .clk            ( clk                )
        , .reset          ( reset              )
        , .increment      ( increment          )
        , .read_address   ( read_address       )
        , .read_value     ( counter_read_value )
        , .csr_wb_request ( csr_wb_request     )
        );

      logic event_selected;

      assign event_selected    = read_address == csr_addr_t'(EVENT_ADDRESS);
      assign hpm_read_value[i] = event_selected ? event_selector : counter_read_value;
    end
  endgenerate

  // only the counter whose address matches drives a non-zero value, so the read value is the
  // OR of all of them
  assign read_value = mcycle_read_value
                    | minstret_read_value
                    | hpm_read_value[3]
                    | hpm_read_value[4]
                    | hpm_read_value[5]
                    | hpm_read_value[6]
                    | hpm_read_value[7]
                    | hpm_read_value[8]
                    | hpm_read_value[9]
                    | hpm_read_value[10]
                    | hpm_read_value[11]
                    | hpm_read_value[12]
                    | hpm_read_value[13]
                    | hpm_read_value[14]
                    | hpm_read_value[15]
                    | hpm_read_value[16]
                    | hpm_read_value[17]
                    | hpm_read_value[18]
                    | hpm_read_value[19]
                    | hpm_read_value[20]
                    | hpm_read_value[21]
                    | hpm_read_value[22]
                    | hpm_read_value[23]
                    | hpm_read_value[24]
                    | hpm_read_value[25]
                    | hpm_read_value[26]
                    | hpm_read_value[27]
                    | hpm_read_value[28]
                    | hpm_read_value[29]
                    | hpm_read_value[30]
                    | hpm_read_value[31];

endmodule
