`include "src/headers/params.svh"
`include "src/headers/types.svh"

module Decode
  ( if_to_id_if.Decode IF_to_ID
  , input wire clk
  , input wire reset
  , input wire [4:0] rd
  , input data_t data
  , input wire zero_flag
  , input data_t alu_result
  , id_to_ex_if.Decode ID_to_EX
  );

  wire         cfsm__pc_update;
  wire         cfsm__reg_write;
  wire         cfsm__ir_write;
  pc_src_t     cfsm__pc_src;
  result_src_t cfsm__result_src;

  opcode_t opcode;
  imm_t    imm_ext;
  reg [2:0] funct3;
  reg [6:0] funct7;

  data_t rd1;
  data_t rd2;

  adr_src_t cfsm__adr_src;
  wire [3:0] __tmp_MemWrite;
  wire __tmp_Branch;
  wire [1:0] __tmp_ALUSrcA, __tmp_ALUSrcB;
  wire [3:0] __tmp_ALUControl;
  wire [1:0] __tmp_ResultSrc;
  wire [4:0] __tmp_FSMState;
  reg  [4:0] rs1, rs2;

  logic [3:0] MemWriteByteAddress;

  instr_t instruction = IF_to_ID.instruction;

  ControlFSM control_fsm
    ( .opcode     ( opcode           )
    , .clk        ( clk              )
    , .reset      ( reset            )
    , .zero_flag  ( zero_flag        )
    , .MemWriteByteAddress ( MemWriteByteAddress )
    , .funct3     ( funct3           )
    , .alu_result ( alu_result       )
    , .AdrSrc     ( cfsm__adr_src    )
    , .IRWrite    ( cfsm__ir_write   )
    , .RegWrite   ( cfsm__reg_write  )
    , .PCUpdate   ( cfsm__pc_update  )
    , .pc_src     ( cfsm__pc_src     )
    , .MemWrite   ( __tmp_MemWrite   )
    , .Branch     ( __tmp_Branch     )
    , .ALUSrcA    ( __tmp_ALUSrcA    )
    , .ALUSrcB    ( __tmp_ALUSrcB    )
    , .ResultSrc  ( cfsm__result_src )
    , .FSMState   ( __tmp_FSMState   )
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
    , .Addr3           ( rd               )
    , .clk             ( clk              )
    , .reset           ( reset            )
    , .regWrite        ( cfsm__reg_write  )
    , .dataIn          ( data           )
    , .baseAddr        ( rd1              )
    , .writeData       ( rd2              )
    );

    always @(posedge clk)
    if (reset) begin
        ID_to_EX.ALUSrcA <= 'b0;
        ID_to_EX.ALUSrcB <= 'b0;
        ID_to_EX.ResultSrc <= 'b0;
        ID_to_EX.AdrSrc <= 'b0;
        ID_to_EX.pc_update <= 'b0;
        ID_to_EX.pc_src <= 'b0;
        ID_to_EX.IRWrite <= 'b0;
        ID_to_EX.Branch <= 'b0;
        ID_to_EX.MemWriteByteAddress <= 'b0;
        ID_to_EX.FSMState <= 'b0;
        ID_to_EX.MemWrite <= 'b0;
        ID_to_EX.RegWrite <= 'b0;
        ID_to_EX.ALUControl <= 'b0;
        ID_to_EX.funct3 <= 'b0;
        ID_to_EX.funct7 <= 'b0;
        ID_to_EX.rd1 <= 'b0;
        ID_to_EX.rd2 <= 'b0;
        ID_to_EX.rd <= 'b0;
        ID_to_EX.rs1 <= 'b0;
        ID_to_EX.rs2 <= 'b0;
        ID_to_EX.imm_ext <= 'b0;
    end
    else begin
        ID_to_EX.ALUSrcA <= __tmp_ALUSrcA;
        ID_to_EX.ALUSrcB <= __tmp_ALUSrcB;
        ID_to_EX.ResultSrc <= cfsm__result_src;
        ID_to_EX.AdrSrc <= cfsm__adr_src;
        ID_to_EX.pc_update <= cfsm__pc_update;
        ID_to_EX.pc_src <= cfsm__pc_src;
        ID_to_EX.IRWrite <= cfsm__ir_write;
        ID_to_EX.Branch <= __tmp_Branch;
        ID_to_EX.MemWriteByteAddress <= MemWriteByteAddress;
        ID_to_EX.FSMState <= __tmp_FSMState;
        ID_to_EX.MemWrite <= __tmp_MemWrite;
        ID_to_EX.RegWrite <= cfsm__reg_write;
        ID_to_EX.ALUControl <= __tmp_ALUControl;
        ID_to_EX.funct3 <= funct3;
        ID_to_EX.funct7 <= funct7;
        ID_to_EX.rd1 <= rd1;
        ID_to_EX.rd2 <= rd2;
        ID_to_EX.rd <= rd;
        ID_to_EX.rs1 <= rs1;
        ID_to_EX.rs2 <= rs2;
        ID_to_EX.imm_ext <= imm_ext;
    end

endmodule
