//created by Joonseo Park, for University of Toronto Open Source Society
//A Moore Type Finite State Machine for the RV32I Microprocessor Control Unit

`include "src/types.svh"

module ControlFSM( //same as single cycle control signals

	input opcode_t opcode,
	input wire clk,
	input wire reset,
//    input wire zero_flag,
	output reg RegWriteD,
	output reg [1:0] immSrcD,
 	output reg PCSrcD,
    output reg JumpD,
	output reg MemWriteD,
	output reg BranchD,
	output alu_src_b_t ALUSrcD,
	output reg [2:0] ALUOpD, //to ALU Decoder
	output result_src_t ResultSrcD,
);


logic [10:0] control_signals;
    assign {RegWriteD, immSrcD, ALUSrcD, MemWriteD, ResultSrcD, BranchD, ALUOpD, JumpD} = control_signals;

    always_comb begin
        if (opcode[1:0] == 2'b11) begin //The least two significant bits of opcode for RV32I should always be 11
            case (opcode[6:2])
                5'b0:     control_signals = 11'b1_00_1_0_01_0_00_0; //I_type -> Load
                5'b00100: control_signals = 11'b1_00_1_0_00_0_10_0; //I_type -> ALU
                5'b01000: control_signals = 11'b0_01_1_1_00_0_00_0; //S_type
                5'b01100: control_signals = 11'b1_00_0_0_00_0_10_0; //R_type
                5'b11000: control_signals = 11'b0_10_0_0_00_1_01_0; //B_type
                5'b11011: control_signals = 11'b1_11_0_0_10_0_00_1; //J_type
                default: control_signals = 11'b0; 
            endcase
        end
        else begin
            control_signals = 11'bx_xx_x_x_xx_x_xx_x; 
        end
            
    end


endmodule