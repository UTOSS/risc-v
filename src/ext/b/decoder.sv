`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"
/* verilator lint_off DECLFILENAME */
module ext__b__decoder
/* verilator lint_on DECLFILENAME */
  ( input [2:0] funct3
  , input [6:0] funct7
  , input opcode_t opcode
  /* verilator lint_off UNUSEDSIGNAL */
  , input reg_t rd
  /* verilator lint_on UNUSEDSIGNAL */
  , input reg_t rs2
  , output ext__b__types::b_alu_control_t b_alu_control
  );

  import ext__b__types::*;

  b_alu_control_t zba_control;
  b_alu_control_t zbb_control;
  b_alu_control_t zbkb_control;

  ext__b__zba_decoder u_ext__b__zba_decoder
    ( .funct3        ( funct3      )
    , .funct7        ( funct7      )
    , .opcode        ( opcode      )
    , .b_alu_control ( zba_control )
    );

  ext__b__zbb_decoder u_ext__b__zbb_decoder
    ( .funct3        ( funct3      )
    , .funct7        ( funct7      )
    , .opcode        ( opcode      )
    , .rs2           ( rs2         )
    , .b_alu_control ( zbb_control )
    );

  ext__b__zbkb_decoder u_ext__b__zbkb_decoder
    ( .funct3        ( funct3       )
    , .funct7        ( funct7       )
    , .opcode        ( opcode       )
    , .rs2           ( rs2          )
    , .b_alu_control ( zbkb_control )
    );

  always_comb
    if (zba_control != B_ALU_CTRL__NONE) b_alu_control = zba_control;
    else if (zbb_control != B_ALU_CTRL__NONE) b_alu_control = zbb_control;
    else b_alu_control = zbkb_control;

endmodule
