`include "src/headers/params.vh"
`include "src/headers/types.svh"

interface id_to_ex_if (input clk);
    alu_src_a_t ALUSrcA;
    alu_src_b_t ALUSrcB;
    result_src_t ResultSrc;
    adr_src_t AdrSrc;
    logic pc_update;
    pc_src_t pc_src;
    logic IRWrite;
    logic Branch;
    logic [3:0] MemWriteByteAddress;
    logic [4:0] FSMState;
    logic [3:0] MemWrite;
    logic RegWrite;
    logic [3:0] ALUControl;
    logic [2:0] funct3;
    logic [6:0] funct7;
    data_t rd1;
    data_t rd2;
    imm_t imm_ext;

    modport Decode(
        input clk,
        output ALUSrcA,
        output ALUSrcB,
        output ResultSrc,
        output AdrSrc,
        output pc_update,
        output pc_src,
        output IRWrite,
        output Branch,
        output MemWriteByteAddress,
        output FSMState,
        output MemWrite,
        output RegWrite,
        output ALUControl,
        output funct3,
        output funct7,
        output rd1,
        output rd2,
        output imm_ext
    );

    modport Execute(
        input clk,
        input ALUSrcA,
        input ALUSrcB,
        input ResultSrc,
        input AdrSrc,
        input pc_update,
        input pc_src,
        input IRWrite,
        input Branch,
        input MemWriteByteAddress,
        input FSMState,
        input MemWrite,
        input RegWrite,
        input ALUControl,
        input funct3,
        input funct7,
        input rd1,
        input rd2,
        input imm_ext
    );

endinterface