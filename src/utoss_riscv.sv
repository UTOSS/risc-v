`include "src/types.svh"

module utoss_riscv
  ( input wire clk
  , input wire reset

  // memory interface begin
  , output addr_t memory__address
  , output data_t memory__write_data
  , output logic  memory__write_enable
  , input  data_t memory__read_data
  // memory interface end
  );

  wire         cfsm__pc_update;
  wire         cfsm__reg_write;
  wire         cfsm__ir_write;
  pc_src_t     cfsm__pc_src;
  result_src_t cfsm__result_src;

  addr_t   pc_cur;
  data_t   data;
  instr_t  instruction;
  opcode_t opcode;
  imm_t    imm_ext;
  reg [2:0] funct3;

  integer byteindex;

  data_t result;
  data_t mem_load_result;

  data_t rd1;
  data_t rd2;

  data_t alu_input_a;
  data_t alu_input_b;
  data_t alu_result;
  data_t alu_out;

  addr_t pc_old;

  wire alu__zero_flag;

  adr_src_t cfsm__adr_src;
  wire __tmp_Branch;
  wire [1:0] __tmp_ALUSrcA, __tmp_ALUSrcB;
  wire [2:0] __tmp_ALUOp;
  wire [3:0] __tmp_ALUControl;
  wire [1:0] __tmp_ResultSrc;
  wire [3:0] __tmp_FSMState;
  data_t     dataA, dataB;
  reg  [4:0] rd, rs1, rs2;

  assign memory__write_data = dataB;

  ControlFSM control_fsm
    ( .opcode    ( opcode               )
    , .clk       ( clk                  )
    , .reset     ( reset                )
    , .zero_flag ( alu__zero_flag       )
    , .AdrSrc    ( cfsm__adr_src        )
    , .IRWrite   ( cfsm__ir_write       )
    , .RegWrite  ( cfsm__reg_write      )
    , .PCUpdate  ( cfsm__pc_update      )
    , .pc_src    ( cfsm__pc_src         )
    , .MemWrite  ( memory__write_enable )
    , .Branch    ( __tmp_Branch         )
    , .ALUSrcA   ( __tmp_ALUSrcA        )
    , .ALUSrcB   ( __tmp_ALUSrcB        )
    , .ALUOp     ( __tmp_ALUOp          )
    , .ResultSrc ( cfsm__result_src     )
    , .FSMState  ( __tmp_FSMState       )
    );

  fetch fetch
    ( .clk             ( clk             )
    , .reset           ( reset           )
    , .cfsm__pc_update ( cfsm__pc_update )
    , .alu_result_for_pc ( alu_out )
    , .cfsm__pc_src    ( cfsm__pc_src    )
    , .cfsm__ir_write  ( cfsm__ir_write  )
    , .imm_ext         ( imm_ext         )

    // outputs
    , .pc_cur          ( pc_cur          )
    , .pc_old          ( pc_old          )
    );

  always @(*) begin
    case (cfsm__adr_src)
      ADR_SRC__PC:     memory__address = pc_cur;
      ADR_SRC__RESULT: memory__address = result;
    endcase
  end

  always @(posedge clk) begin
    if (cfsm__ir_write) begin
      instruction <= memory__read_data;
    end
  end

  MemoryLoader MemLoad
  ( .memory_data       ( memory__read_data )
  , .memory_address    ( memory__address   )
  , .mem_load_result   ( mem_load_result   )
  , .funct3            ( funct3            )
  );

  always @(posedge clk) begin
    data <= mem_load_result;
  end

  Instruction_Decode instruction_decode
    ( .instr           ( instruction      )
    , .opcode          ( opcode           )
    , .funct3          ( funct3           )
    , .ALUControl      ( __tmp_ALUControl )
    , .imm_ext         ( imm_ext          )
    , .rd              ( rd               )
    , .rs1             ( rs1              )
    , .rs2             ( rs2              )
    );

  registerFile RegFile
    ( .Addr1           ( rs1              )
    , .Addr2           ( rs2              )
    , .Addr3           ( rd               )
    , .clk             ( clk              )
    , .reset           ( reset            )
    , .regWrite        ( cfsm__reg_write  )
    , .dataIn          ( result           )
    , .baseAddr        ( rd1              )
    , .writeData       ( rd2              )
    );

  ALU alu
    ( .a              ( alu_input_a      )
    , .b              ( alu_input_b      )
    , .alu_control    ( __tmp_ALUControl )
    , .out            ( alu_result       )
    , .zeroE          ( alu__zero_flag   )
    );

  always @(posedge clk) begin
    alu_out <= alu_result;
  end

  always @(*) begin
    case (__tmp_ALUSrcA)
      ALU_SRC_A__PC:     alu_input_a = pc_cur;
      ALU_SRC_A__OLD_PC: alu_input_a = pc_old;
      ALU_SRC_A__RD1:    alu_input_a = dataA;
      ALU_SRC_A__ZERO:   alu_input_a = 32'b0;

      default:           alu_input_a = 32'hxxxxxxxx;
    endcase
  end

  always @(*) begin
    case (__tmp_ALUSrcB)
      ALU_SRC_B__RD2:     alu_input_b = dataB;
      ALU_SRC_B__IMM_EXT: alu_input_b = imm_ext;
      ALU_SRC_B__4:       alu_input_b = 32'd4;
      default:            alu_input_b = 32'hxxxxxxxx;
    endcase
  end

  always @(*) begin
    case (cfsm__result_src)
      RESULT_SRC__ALU_OUT:    result = alu_out;
      RESULT_SRC__DATA:       result = data;
      RESULT_SRC__ALU_RESULT: result = alu_result;
      default:                result = 32'hxxxxxxxx;
    endcase
  end

  always @(posedge clk) begin
    dataA <= rd1;
    dataB <= rd2;
  end

endmodule
