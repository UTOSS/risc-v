`include "src/headers/params.vh"
`include "src/headers/types.svh"

module Decode
  ( input instr_t instruction
  , input wire clk
  , input wire reset
  , input data_t data
  , input wire zero_flag
  , input data_t alu_result
  , id_to_ex_if.Decode ID_to_EX
  );

  reg [4:0] rd, rs1, rs2;
  wire [6:0] opcode;

  Instruction_Decode instruction_decode
    ( .instr           ( instruction             )
    , .opcode          ( opcode                  )
    , .funct3          ( ID_to_EX.funct3         )
    , .funct7          ( ID_to_EX.funct7         )
    , .ALUControl      ( ID_to_EX.ALUControl     )
    , .imm_ext         ( ID_to_EX.imm_ext        )
    , .rd              ( rd                      )
    , .rs1             ( rs1                     )
    , .rs2             ( rs2                     )
    );

  registerFile RegFile
    ( .Addr1           ( rs1                   )
    , .Addr2           ( rs2                   )
    , .Addr3           ( rd                    )
    , .clk             ( clk                   )
    , .reset           ( reset                 )
    , .regWrite        ( ID_to_EX.RegWrite     )
    , .dataIn          ( data                  )
    , .baseAddr        ( ID_to_EX.rd1          )
    , .writeData       ( ID_to_EX.rd2          )
    );

  ControlFSM control_fsm
    ( .opcode              ( opcode                          )
    , .clk                 ( clk                             )
    , .reset               ( reset                           )
    , .zero_flag           ( zero_flag                       )
    , .MemWriteByteAddress ( ID_to_EX.MemWriteByteAddress    )
    , .funct3              ( ID_to_EX.funct3                 )
    , .alu_result          ( alu_result                      )
    , .AdrSrc              ( ID_to_EX.AdrSrc                 )
    , .IRWrite             ( ID_to_EX.IRWrite                )
    , .RegWrite            ( ID_to_EX.RegWrite               )
    , .PCUpdate            ( ID_to_EX.pc_update              )
    , .pc_src              ( ID_to_EX.pc_src                 )
    , .MemWrite            ( ID_to_EX.MemWrite               )
    , .Branch              ( ID_to_EX.Branch                 )
    , .ALUSrcA             ( ID_to_EX.ALUSrcA                )
    , .ALUSrcB             ( ID_to_EX.ALUSrcB                )
    , .ResultSrc           ( ID_to_EX.ResultSrc              )
    , .FSMState            ( ID_to_EX.FSMState               )
    );

endmodule