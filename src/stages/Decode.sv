`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/id_to_ex_if.svh"

module Decode
  ( input if_to_id_t IF_to_ID
  , input wire clk
  , input wire reset
  , input wire [4:0] rd_wb // rd from writeback
  , input wire RegWriteW // regWrite from writeback stage
  , input data_t data
  , output reg [2:0] funct3
  , output id_to_ex_t ID_to_EX
  );

  wire                    cfsm__reg_write;
  write_back_result_src_t cfsm__result_src;
  wire                    cfsm__mem_write;
  wire                    cfsm__jump;
  wire                    cfsm__branch;
  execute_alu_src_b_t     cfsm__ALUSrcB;

  opcode_t opcode;
  imm_t    imm_ext;
  reg [6:0] funct7;

  wire [4:0] rd;

  data_t rd1;
  data_t rd2;

  reg  [4:0] rs1;
  reg  [4:0] rs2;

  instr_t instruction;
  
  assign instruction = IF_to_ID.instruction;

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
    , .alu_src_b  ( cfsm__ALUSrcB    )
    );

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
    , .regWrite        ( RegWriteW        )
    , .dataIn          ( data             )
    , .baseAddr        ( rd1              )
    , .writeData       ( rd2              )
    );

    assign ID_to_EX.ALUSrcB             = cfsm__ALUSrcB;
    assign ID_to_EX.ResultSrc           = cfsm__result_src;
    assign ID_to_EX.Branch              = cfsm__branch;
    assign ID_to_EX.Jump                = cfsm__jump;
    assign ID_to_EX.MemWrite            = cfsm__mem_write;
    assign ID_to_EX.RegWrite            = cfsm__reg_write;
    assign ID_to_EX.ALUControl          = __tmp_ALUControl;
    assign ID_to_EX.rd1                 = rd1;
    assign ID_to_EX.rd2                 = rd2;
    assign ID_to_EX.rd                  = rd;
    assign ID_to_EX.rs1                 = rs1;
    assign ID_to_EX.rs2                 = rs2;
    assign ID_to_EX.imm_ext             = imm_ext;
    assign ID_to_EX.pc_cur              = IF_to_ID.pc_cur;
    assign ID_to_EX.pc_plus_4           = IF_to_ID.pc_plus_4;

endmodule
