`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/id_to_ex_if.svh"

module Decode
  ( input if_to_id_t IF_to_ID
  , input wire clk
  , input wire reset
  , input wire [4:0] rd_wb // rd from writeback
  , input data_t data
  , input wire zero_flag
  , input data_t alu_result
  , output id_to_ex_t ID_to_EX
  );

  wire                    cfsm__pc_update;
  wire                    cfsm__reg_write;
  wire                    cfsm__ir_write;
  pc_src_t                cfsm__pc_src;
  write_back_result_src_t cfsm__result_src;
  wire                    cfsm__mem_write;
  wire                    cfsm__jump;
  wire                    cfsm__branch;

  opcode_t opcode;
  imm_t    imm_ext;
  reg [2:0] funct3;
  reg [6:0] funct7;

  wire [4:0] rd;

  data_t rd1;
  data_t rd2;

  adr_src_t cfsm__adr_src;
  wire [3:0] __tmp_MemWrite;
  wire __tmp_Branch;
  alu_src_a_t __tmp_ALUSrcA;
  execute_alu_src_b_t __tmp_ALUSrcB;
  wire [3:0] __tmp_ALUControl;
  wire [1:0] __tmp_ResultSrc;
  wire [4:0] __tmp_FSMState;
  reg  [4:0] rs1, rs2;

  logic [3:0] MemWriteByteAddress;

  instr_t instruction = IF_to_ID.instruction;

  control_fsm_pipelined u_ctrl
    ( .clk   ( clk   )
    , .reset ( reset )

    , .opcode ( opcode )
    , .func3  ( func3  )

    , .reg_write  ( cfsm__reg_write  )
    , .result_src ( cfsm__result_src )
    , .mem_write  ( cfsm__mem_write  )
    , .jump       ( cfsm__jump       )
    , .branch     ( cfsm__branch     )
    , .alu_src    ( __tmp_ALUSrcB    )
    );

  // TODO: remove once we are sure all the signals are properly passed to execute stage
  // ControlFSM control_fsm
  //   ( .opcode     ( opcode           )
  //   , .clk        ( clk              )
  //   , .reset      ( reset            )
  //   , .zero_flag  ( zero_flag        )
  //   , .MemWriteByteAddress ( MemWriteByteAddress )
  //   , .funct3     ( funct3           )
  //   , .alu_result ( alu_result       )
  //   , .AdrSrc     ( cfsm__adr_src    )
  //   , .IRWrite    ( cfsm__ir_write   )
  //   , .RegWrite   ( cfsm__reg_write  )
  //   , .PCUpdate   ( cfsm__pc_update  )
  //   , .pc_src     ( cfsm__pc_src     )
  //   , .MemWrite   ( __tmp_MemWrite   )
  //   , .Branch     ( __tmp_Branch     )
  //   , .ALUSrcA    ( __tmp_ALUSrcA    )
  //   , .ALUSrcB    ( __tmp_ALUSrcB    )
  //   , .ResultSrc  ( cfsm__result_src )
  //   , .FSMState   ( __tmp_FSMState   )
  //   );

  Instruction_Decode instruction_decode
    ( .instr           ( instruction      )
    , .opcode          ( opcode           )
    , .funct3          ( funct3           )
    , .funct7          ( funct7           )
    , .ALUControl      ( __tmp_ALUControl )
    , .imm_ext         ( imm_ext          )
    , .rd              ( rd               )
    , .rs1             ( rs1              )
    , .rs2             ( rs2              )
    );

  registerFile RegFile
    ( .Addr1           ( rs1              )
    , .Addr2           ( rs2              )
    , .Addr3           ( rd_wb            )
    , .clk             ( clk              )
    , .reset           ( reset            )
    , .regWrite        ( cfsm__reg_write  )
    , .dataIn          ( data           )
    , .baseAddr        ( rd1              )
    , .writeData       ( rd2              )
    );

    assign ID_to_EX.ALUSrcA             = __tmp_ALUSrcA;
    assign ID_to_EX.ALUSrcB             = __tmp_ALUSrcB;
    assign ID_to_EX.ResultSrc           = cfsm__result_src;
    assign ID_to_EX.AdrSrc              = cfsm__adr_src;
    assign ID_to_EX.pc_update           = cfsm__pc_update;
    assign ID_to_EX.pc_src              = cfsm__pc_src;
    assign ID_to_EX.IRWrite             = cfsm__ir_write;
    assign ID_to_EX.Branch              = __tmp_Branch;
    assign ID_to_EX.MemWriteByteAddress = MemWriteByteAddress;
    assign ID_to_EX.FSMState            = __tmp_FSMState;
    assign ID_to_EX.MemWrite            = __tmp_MemWrite;
    assign ID_to_EX.RegWrite            = cfsm__reg_write;
    assign ID_to_EX.ALUControl          = __tmp_ALUControl;
    assign ID_to_EX.funct3              = funct3;
    assign ID_to_EX.funct7              = funct7;
    assign ID_to_EX.rd1                 = rd1;
    assign ID_to_EX.rd2                 = rd2;
    assign ID_to_EX.rd                  = rd;
    assign ID_to_EX.rs1                 = rs1;
    assign ID_to_EX.rs2                 = rs2;
    assign ID_to_EX.imm_ext             = imm_ext;
    assign ID_to_EX.pc_cur              = IF_to_ID.pc_cur;

endmodule
