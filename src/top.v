`include "src/types.svh"

module top ( input wire clk
           , input wire reset
           );

  wire     cfsm__pc_update;
  pc_src_t cfsm__pc_src;
  instr_t  instr;
  opcode_t opcode;
  imm_t    imm_ext;

  data_t __tmp_ResultData;

  data_t rs1;
  data_t rs2;

  data_t alu_input_a;
  data_t alu_input_b;

  wire alu__zero_flag;

  wire __tmp_AdrSrc
     , __tmp_IRWrite
     , __tmp_RegWrite
     , __tmp_MemWrite
     , __tmp_Branch;
  wire [1:0] __tmp_ALUSrcA
           , __tmp_ALUSrcB;
  wire [2:0] __tmp_ALUOp;
  wire [3:0] __tmp_ALUControl;
  wire [1:0] __tmp_ResultSrc;
  wire [3:0] __tmp_FSMState;
  data_t __tmp_ALUOut;

  ControlFSM control_fsm
    ( .opcode    ( opcode          )
    , .clk       ( clk             )
    , .reset     ( reset           )
    , .zero_flag ( alu__zero_flag  )
    , .AdrSrc    ( __tmp_AdrSrc    )
    , .IRWrite   ( __tmp_IRWrite   )
    , .RegWrite  ( __tmp_RegWrite  )
    , .PCUpdate  ( cfsm__pc_update )
    , .pc_src    ( cfsm__pc_src    )
    , .MemWrite  ( __tmp_MemWrite  )
    , .Branch    ( __tmp_Branch    )
    , .ALUSrcA   ( __tmp_ALUSrcA   )
    , .ALUSrcB   ( __tmp_ALUSrcB   )
    , .ALUOp     ( __tmp_ALUOp     )
    , .ResultSrc ( __tmp_ResultSrc )
    , .FSMState  ( __tmp_FSMState  )
    );

  fetch fetch
    ( .clk             ( clk             )
    , .reset           ( reset           )
    , .cfsm__pc_update ( cfsm__pc_update )
    , .cfsm__pc_src    ( cfsm__pc_src    )
    , .imm_ext         ( imm_ext         )
    , .instr           ( instr           )
    );

  Instruction_Decode instruction_decode
    ( .instr           ( instr            )
    , .clk             ( clk              )
    , .reset           ( reset            )
    , .ResultData      ( __tmp_ResultData )
    , .opcode          ( opcode           )
    , .ALUControl      ( __tmp_ALUControl )
    , .baseAddr        ( rs1              )
    , .writeData       ( rs2              )
    , .imm_ext         ( imm_ext          )
    );

  ALU alu
    ( .a              ( alu_input_a      )
    , .b              ( alu_input_b      )
    , .alu_control    ( __tmp_ALUControl )
    , .out            ( __tmp_ALUOut     )
    , .zeroE          ( alu__zero_flag   )
    );

  always @(*) begin
    case (__tmp_ALUSrcA)
      2'b00: alu_input_a = 32'd0;
      2'b01: alu_input_a = rs1;
      2'b10: alu_input_a = OldPC;
      default: alu_input_a = 32'hxxxxxxxx;
    endcase
  end

  always @(*) begin
    case (__tmp_ALUSrcB)
      2'b00: alu_input_b = rs2;
      2'b01: alu_input_b = 32'd4;
      2'b10: alu_input_b = imm_ext;
      default: alu_input_b = 32'hxxxxxxxx;
    endcase
  end

  always @(*) begin
    case (__tmp_ResultSrc)
      2'b00: __tmp_ResultData = __tmp_ALUOut;
      2'b01: __tmp_ResultData = Data;
      2'b10: __tmp_ResultData = OldPC;
      default: __tmp_ResultData = 32'hxxxxxxxx;
    endcase
  end

endmodule
