`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/interfaces/id_to_ex_if.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module execute_stage
  ( input id_to_ex_t id_to_ex

  , input hazard_forward_a_t hz_forward_a
  , input hazard_forward_b_t hz_forward_b

  , input data_t wb_result
  , input data_t mem_alu_result

  , output ex_to_if_t ex_to_if
  , output ex_to_mem_t ex_to_mem
  );

  data_t alu_input_a;
  data_t alu_input_b;
  data_t safe_rd1; // hazard-safe version of rd1
  data_t safe_rd2; // hazard-safe version of rd2
  data_t alu_result;
  logic zero_flag;

`ifdef UTOSS_RISCV_ENABLE_B_EXT
  data_t zbb_result;
  logic  zbb_zero_flag;
`endif


  // ALU computation

  always_comb
    case (hz_forward_a)
      HAZARD_FORWARD_A__EXECUTE_RD1:       safe_rd1 = id_to_ex.rd1;
      HAZARD_FORWARD_A__WRITE_BACK_RESULT: safe_rd1 = wb_result;
      HAZARD_FORWARD_A__MEMORY_ALU_RESULT: safe_rd1 = mem_alu_result;
      default:                             safe_rd1 = 'x;
    endcase

  always_comb
    case (hz_forward_b)
      HAZARD_FORWARD_B__EXECUTE_RD2:       safe_rd2 = id_to_ex.rd2;
      HAZARD_FORWARD_B__WRITE_BACK_RESULT: safe_rd2 = wb_result;
      HAZARD_FORWARD_B__MEMORY_ALU_RESULT: safe_rd2 = mem_alu_result;
      default:                             safe_rd2 = 'x;
    endcase

  always_comb
    case (id_to_ex.alu_src_a)
      ALU_SRC_A__RD1: alu_input_a = safe_rd1;
      ALU_SRC_A__PC:  alu_input_a = id_to_ex.pc_cur;
      default:        alu_input_a = 'x;
    endcase

  always_comb
    case (id_to_ex.alu_src_b)
      ALU_SRC_B__RD2:     alu_input_b = safe_rd2;
      ALU_SRC_B__IMM_EXT: alu_input_b = id_to_ex.imm_ext;
      default:            alu_input_b = 'x;
    endcase

  logic [`PROCESSOR_BITNESS - 1:0] alu_result_base;
  logic zero_flag_base;
  ALU alu
    ( .a              ( alu_input_a         )
    , .b              ( alu_input_b         )
    , .alu_control    ( id_to_ex.alu_control )
    , .out            ( alu_result_base          )
    , .zeroE          ( zero_flag_base           ) //added bases for local
    );

`ifdef UTOSS_RISCV_ENABLE_B_EXT
  zbb u_zbb
    ( .a              ( alu_input_a            )
    , .b              ( alu_input_b            )
    , .b_alu_control  ( id_to_ex.b_alu_control )
    , .out            ( zbb_result             )
    , .zeroE          ( zbb_zero_flag          )
    );
`endif
`ifdef UTOSS_RISCV_ENABLE_B_EXT
  always_comb begin
    if (id_to_ex.b_alu_control != ext__b__types::B_ALU_CTRL__NONE) begin
        alu_result = zbb_result;
        zero_flag  = zbb_zero_flag;
    end else begin
        alu_result = alu_result_base;
        zero_flag  = zero_flag_base;
    end
  end
`else
assign alu_result = alu_result_base;
assign zero_flag  = zero_flag_base;
`endif

  typedef enum logic [2:0]
    { FUNCT3__BEQ  = 3'b000
    , FUNCT3__BNE  = 3'b001
    , FUNCT3__BLT  = 3'b100
    , FUNCT3__BGE  = 3'b101
    , FUNCT3__BLTU = 3'b110
    , FUNCT3__BGEU = 3'b111
    } funct3_branch_t;

  logic jump_e;
  logic branch_e;
  pc_src_t pc_src;
  addr_t pc_target;

  assign jump_e = id_to_ex.jump;
  assign branch_e = id_to_ex.branch;

  always_comb
    case (id_to_ex.pc_target_kind)
      PC_TARGET_KIND__RELATIVE: pc_target = id_to_ex.pc_cur + id_to_ex.imm_ext;

      // here the control FSM arranges for the computation to have been done via the ALU, i.e. to
      // add the register value to imm_ext to abvoid building another adder
      PC_TARGET_KIND__ABSOLUTE: pc_target = alu_result;
      default:                  pc_target = addr_t'('x);
    endcase

  logic branch_condition_met;
  always_comb
    case (id_to_ex.funct3)
      FUNCT3__BEQ:               branch_condition_met =  zero_flag;
      FUNCT3__BNE:               branch_condition_met = ~zero_flag;
      FUNCT3__BLT, FUNCT3__BLTU: branch_condition_met =  alu_result[0];
      FUNCT3__BGE, FUNCT3__BGEU: branch_condition_met = ~alu_result[0];
      default:                   branch_condition_met =  zero_flag;
    endcase

  logic should_branch;
  assign should_branch = jump_e | (branch_e & branch_condition_met);

  assign pc_src = should_branch ? PC_SRC__ALU_RESULT : PC_SRC__INCREMENT;

  assign ex_to_mem.result_src   = id_to_ex.result_src;
  assign ex_to_mem.mem_write    = id_to_ex.mem_write;
  assign ex_to_mem.reg_write    = id_to_ex.reg_write;
  assign ex_to_mem.funct3       = id_to_ex.funct3;
  assign ex_to_mem.write_data_e = safe_rd2;
  assign ex_to_mem.rd           = id_to_ex.rd;
  assign ex_to_mem.alu_result   = alu_result;
  assign ex_to_mem.pc_cur       = id_to_ex.pc_cur;
  assign ex_to_mem.pc_plus_4    = id_to_ex.pc_plus_4;
  assign ex_to_if.imm_ext       = id_to_ex.imm_ext;
  assign ex_to_if.pc_src        = pc_src;
  assign ex_to_if.pc_target     = pc_target;
  assign ex_to_if.pc_old        = id_to_ex.pc_cur;

  wire unused = &{id_to_ex.rs1, id_to_ex.rs2};
endmodule
