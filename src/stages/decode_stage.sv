`include "src/timescale.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/id_to_ex_if.svh"

module decode_stage
  ( input  if_to_id_t if_to_id

  , input  wire       clk
  , input  wire       reset

  , input  reg_t      rd_wb // rd from writeback
  , input  wire       reg_write_w // regWrite from writeback stage
  , input  data_t     data

  , output id_to_ex_t id_to_ex

  , output reg_t      rs1
  , output reg_t      rs2
  );

  wire             cfsm__reg_write;
  result_src_t     cfsm__result_src;
  wire             cfsm__mem_write;
  wire             cfsm__jump;
  wire             cfsm__branch;
  pc_target_kind_t cfsm__pc_target_kind;
  alu_src_a_t      cfsm__alu_src_a;
  alu_src_b_t      cfsm__alu_src_b;

  alu_control_t    alu_control;
  logic            is_mul;
  logic            is_div;
`ifdef UTOSS_RISCV__MUL_ENABLED
  ext__m__types::m_mul_control_t mul_control;
`endif
`ifdef UTOSS_RISCV__DIV_ENABLED
  ext__m__types::m_div_control_t div_control;
`endif
`ifdef UTOSS_RISCV_ENABLE_B_EXT
  ext__b__types::b_alu_control_t b_alu_control; //NEW
`endif


  opcode_t opcode;
  imm_t    imm_ext;

  wire [2:0] funct3;

  reg_t rd;

  data_t rd1;
  data_t rd2;

  instr_t instruction;

  assign instruction = if_to_id.instruction;

  control_fsm u_ctrl
    ( .opcode  ( opcode )

    , .reg_write      ( cfsm__reg_write      )
    , .result_src     ( cfsm__result_src     )
    , .mem_write      ( cfsm__mem_write      )
    , .jump           ( cfsm__jump           )
    , .branch         ( cfsm__branch         )
    , .pc_target_kind ( cfsm__pc_target_kind )
    , .alu_src_a      ( cfsm__alu_src_a      )
    , .alu_src_b      ( cfsm__alu_src_b      )
    );

  Instruction_Decode instruction_decode
    ( .instr           ( instruction      )
    , .opcode          ( opcode           )
    , .funct3          ( funct3           )
    , .ALUControl      ( alu_control      )
    , .imm_ext         ( imm_ext          )
    , .rd              ( rd               )
    , .rs1             ( rs1              )
    , .rs2             ( rs2              )
    , .is_mul          ( is_mul           )
    , .is_div          ( is_div           )
`ifdef UTOSS_RISCV__MUL_ENABLED
    , .mul_control     ( mul_control      )
`endif
`ifdef UTOSS_RISCV__DIV_ENABLED
    , .div_control     ( div_control      )
`endif
`ifdef UTOSS_RISCV_ENABLE_B_EXT
    , .b_alu_control   ( b_alu_control    )
`endif
    );

  registerFile RegFile
    ( .Addr1           ( rs1              )
    , .Addr2           ( rs2              )
    , .Addr3           ( rd_wb            )
    , .clk             ( clk              )
    , .reset           ( reset            )
    , .regWrite        ( reg_write_w      )
    , .dataIn          ( data             )
    , .baseAddr        ( rd1              )
    , .writeData       ( rd2              )
    );

  // WB->ID bypass; this is needed in situations where decode is reading the register that
  // write-back stage is about to write to; since register writes happen on clock enge without this
  // decode will pass stale register data to execute stage which the hazard unit will not be able to
  // accomodate since during the following clock cycle the write-back's destination register will
  // already move on to the next instruction
  data_t rd1_safe;
  always_comb
    if (rd_wb == rs1 && reg_write_w && rd_wb != 0) rd1_safe = data;
    else                                           rd1_safe = rd1;

  data_t rd2_safe;
  always_comb
    if (rd_wb == rs2 && reg_write_w && rd_wb != 0) rd2_safe = data;
    else                                           rd2_safe = rd2;

  assign id_to_ex.alu_src_a      = cfsm__alu_src_a;
  assign id_to_ex.alu_src_b      = cfsm__alu_src_b;
  assign id_to_ex.result_src     = cfsm__result_src;
  assign id_to_ex.branch         = cfsm__branch;
  assign id_to_ex.jump           = cfsm__jump;
  assign id_to_ex.pc_target_kind = cfsm__pc_target_kind;
  assign id_to_ex.mem_write      = cfsm__mem_write;
  assign id_to_ex.reg_write      = cfsm__reg_write;
  assign id_to_ex.alu_control    = alu_control;
  assign id_to_ex.funct3         = funct3;
  assign id_to_ex.rd1            = rd1_safe;
  assign id_to_ex.rd2            = rd2_safe;
  assign id_to_ex.rd             = rd;
  assign id_to_ex.rs1            = rs1;
  assign id_to_ex.rs2            = rs2;
  assign id_to_ex.imm_ext        = imm_ext;
  assign id_to_ex.pc_cur         = if_to_id.pc_cur;
  assign id_to_ex.pc_plus_4      = if_to_id.pc_plus_4;
  assign id_to_ex.is_mul         = is_mul;
  assign id_to_ex.is_div         = is_div;
`ifdef UTOSS_RISCV__MUL_ENABLED
  assign id_to_ex.mul_control    = mul_control;
`endif
`ifdef UTOSS_RISCV__DIV_ENABLED
  assign id_to_ex.div_control    = div_control;
`endif
`ifdef UTOSS_RISCV_ENABLE_B_EXT
  assign id_to_ex.b_alu_control = b_alu_control;
`endif

endmodule
