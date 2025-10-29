`include "src/types.svh"

module top ( input wire clk
           , input wire reset
           );

  wire         cfsm__pc_update;
  wire         cfsm__reg_write;
  wire         cfsm__ir_write;
  pc_src_t     cfsm__pc_src;
  result_src_t cfsm__result_src;

  addr_t   pc_cur;

  addr_t  pc_F;
  addr_t  pc_D;
  addr_t  pc_E;


//  addr_t   memory_address;
  data_t   memory_data;
  data_t   data;
  instr_t  instruction;
  opcode_t opcode;
  imm_t    imm_ext;

  data_t result;

  data_t rd1;
  data_t rd2;

  data_t alu_input_a;
  data_t alu_input_b;
  data_t alu_result;
  data_t alu_out;

  addr_t pc_old;

  wire alu__zero_flag;

  adr_src_t cfsm__adr_src;
  wire __tmp_MemWrite
     , __tmp_Branch;
  wire [1:0] __tmp_ALUSrcA
           , __tmp_ALUSrcB;
  wire [2:0] __tmp_ALUOp;
  wire [3:0] __tmp_ALUControl;
  wire [1:0] __tmp_ResultSrc;
  wire [3:0] __tmp_FSMState;
  logic [31:0] dataA
			 ,dataB;

  logic [1:0] immSrcD; //not wired to anywhere; immext is done in fetch

  ControlFSM control_fsm
    ( .opcode    ( opcode           )
    , .clk       ( clk              )
    , .reset     ( reset            )
//    , .zero_flag ( alu__zero_flag   )
//    , .AdrSrc    ( cfsm__adr_src    )
//    , .IRWrite   ( cfsm__ir_write   )
    , .RegWriteD  ( cfsm__reg_write  )
    , .immSrcD    ( immSrcD         )
//    , .PCUpdate  ( cfsm__pc_update  )
    , .PCSrcD    ( cfsm__pc_src     )
    , .JumpD     ( JumpE            )
    , .MemWriteD  ( __tmp_MemWrite   )
    , .BranchD    ( __tmp_Branch     )
    , .ALUSrcD   ( __tmp_ALUSrcB    )
    , .ALUOpD     ( __tmp_ALUOp      )
    , .ResultSrcD ( cfsm__result_src_e )
    , .ResultSrcD ( cfsm__result_src_m )
    );

  //pipeline control signals
	always@(posedge clk) //D-E
	begin
    if (FlushE) begin
        RegWriteE <= 1'b0;
        MemWriteE <= 1'b0;
        ResultSrcE <= 2'b00;
        BranchE <= 1'b0;
        JumpE <= 1'b0;
        ALUOpE <= 3'b000;
        ALUSrcE <= 2'b00;
    end
    else begin
		RegWriteE <= RegWriteD;
		MemWriteE <= MemWriteD;
		ResultSrcE <= ResultSrcD;
		BranchE <= BranchD;
		JumpE <= JumpD;
		ALUOpE <= ALUOpD;
		ALUSrcE <= ALUSrcD;
    end
	end

  always@(posedge clk)
  begin
    PCSrcE <= (BranchE & alu__zero_flag) | JumpE;
  end

  always@(posedge clk) //E-M, M-W
  begin
  	RegWriteM <= RegWriteE;
  	MemWriteM <= MemWriteE;
    ResultSrcM <= ResultSrcE;
    alu_resultM <= alu_result;
    RegWriteW <= RegWriteM;
  end

  		
/*  fetch fetch
    ( .clk             ( clk             )
    , .reset           ( reset           )
//    , .cfsm__pc_update ( cfsm__pc_update )
//    , .cfsm__pc_src    ( cfsm__pc_src    )
//    , .cfsm__ir_write  ( cfsm__ir_write  )
    , .imm_ext         ( imm_ext         )

    // outputs
    , .pc_cur          ( pc_cur          )
    , .pc_old          ( pc_old          )
    );

  */
/*
  always @(*) begin
    case (cfsm__adr_src)
      ADR_SRC__PC:     memory_address = pc_cur;
      ADR_SRC__RESULT: memory_address = result;
    endcase
  end
  */

  MA memory // instructions and data
    ( .A   ( alu_resultM   )
    , .WD  ( dataB          )
    , .WE  ( __tmp_MemWrite )
    , .CLK ( clk            )

    // outputs
    , .RD  ( memory_data    )
    );

/*
  always @(posedge clk) begin
    if (cfsm__ir_write) begin
      instruction <= memory_data;
    end
  end
*/

  always @(posedge clk) begin
    data <= memory_data;
  end

  Instruction_Decode instruction_decode
    ( .instr           ( instruction      )
    , .clk             ( clk              )
    , .reset           ( reset            )
    , .ResultData      ( result           )
    , .reg_write       ( cfsm__reg_write  )
    , .opcode          ( opcode           )
    , .ALUControl      ( __tmp_ALUControl )
    , .baseAddr        ( rd1              )
    , .writeData       ( rd2              )
    , .imm_ext         ( imm_ext          )
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

  hazard_unit hazard_unit 
  ( .clk              ( clk             ) 
	, .Rs1E             ( Rs1E            )
	, .RdM              ( RdM             ) 
	, .RdW              ( RdW             )
	, .RegWriteM        ( RegWrite        ) 
	, .ResultSrcE       ( ResultSrcE      ) 
	, .Rs1D             ( Rs1D            )
	, .Rs2D             ( Rs2D            ) 
	, .RdE              ( RdE             ) 
	, .PCSrcE           ( PCSrcE          ) 
	, .ForwardAE        ( ForwardAE       )
	, .lwStall          ( lwStall         )
	, .StallF           ( StallF          )
	, .StallD           ( StallD          )
	, .FlushD           ( FlushD          )
	, .FlushE           ( FlushE          )
	)

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
