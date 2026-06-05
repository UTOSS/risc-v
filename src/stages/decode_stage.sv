`include "src/timescale.svh"
`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/id_to_ex_if.svh"

module decode_stage
  ( input  if_to_id_t if_to_id

  , input  wire       clk
  , input  wire       reset

  , input  wire [4:0] rd_wb // rd from writeback
  , input  wire       reg_write_w // regWrite from writeback stage
  , input  data_t     data

  , output id_to_ex_t id_to_ex

  , output reg [4:0] rs1
  , output reg [4:0] rs2
  );

  wire             cfsm__reg_write;
  result_src_t     cfsm__result_src;
  wire             cfsm__mem_write;
  wire             cfsm__jump;
  wire             cfsm__branch;
  pc_target_kind_t cfsm__pc_target_kind;
  alu_src_a_t      cfsm__alu_src_a;
  alu_src_b_t      cfsm__alu_src_b;

  alu_control_t    alu_control;

  opcode_t opcode;
  imm_t    imm_ext;
  csr_addr_t csr_addr;
  data_t   csr_read_data;

  wire [2:0] funct3;

  wire [4:0] rd;

  data_t rd1;
  data_t rd2;

  instr_t instruction;

  assign instruction = if_to_id.instruction;

  control_fsm u_ctrl
    ( .opcode  ( opcode )
    , .funct3  ( funct3 )

    , .reg_write      ( cfsm__reg_write      )
    , .result_src     ( cfsm__result_src     )
    , .mem_write      ( cfsm__mem_write      )
    , .jump           ( cfsm__jump           )
    , .branch         ( cfsm__branch         )
    , .pc_target_kind ( cfsm__pc_target_kind )
    , .alu_src_a      ( cfsm__alu_src_a      )
    , .alu_src_b      ( cfsm__alu_src_b      )
    );

  Instruction_Decode instruction_decode
    ( .instr           ( instruction      )
    , .opcode          ( opcode           )
    , .funct3          ( funct3           )
    , .ALUControl      ( alu_control      )
    , .imm_ext         ( imm_ext          )
    , .csr_addr        ( csr_addr         )
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
    , .regWrite        ( reg_write_w      )
    , .dataIn          ( data             )
    , .baseAddr        ( rd1              )
    , .writeData       ( rd2              )
    );

`ifdef UTOSS_RISCV__ZICSR_ENABLED
  data_t csr_write_data;
  logic  csr_write_enable;

  CSRFile u_csr_file
    ( .addr            ( csr_addr         )
    , .clk             ( clk              )
    , .reset           ( reset            )
    , .csr_write_enable( csr_write_enable )
    , .data_in         ( csr_write_data   )
    , .data_out        ( csr_read_data    )
    );

  always_comb begin
    csr_write_enable = 1'b0;
    csr_write_data   = data_t'(0);

    if (opcode == SYSTEM) begin
      case (funct3)
        3'b001: begin
          csr_write_enable = 1'b1;
          csr_write_data   = rd1_safe;
        end
        3'b010: begin
          csr_write_enable = (rs1 != 5'd0);
          csr_write_data   = csr_read_data | rd1_safe;
        end
        3'b011: begin
          csr_write_enable = (rs1 != 5'd0);
          csr_write_data   = csr_read_data & ~rd1_safe;
        end
        default: begin
          csr_write_enable = 1'b0;
          csr_write_data   = data_t'(0);
        end
      endcase
    end
  end
`else
  assign csr_read_data = data_t'(0);
`endif

  // WB->ID bypass; this is needed in situations where decode is reading the register that
  // write-back stage is about to write to; since register writes happen on clock enge without this
  // decode will pass stale register data to execute stage which the hazard unit will not be able to
  // accomodate since during the following clock cycle the write-back's destination register will
  // already move on to the next instruction
  data_t rd1_safe;
  always_comb
    if (rd_wb == rs1 && reg_write_w && rd_wb != 0) rd1_safe = data;
    else                                           rd1_safe = rd1;

  data_t rd2_safe;
  always_comb
    if (rd_wb == rs2 && reg_write_w && rd_wb != 0) rd2_safe = data;
    else                                           rd2_safe = rd2;

  assign id_to_ex.alu_src_a      = cfsm__alu_src_a;
  assign id_to_ex.alu_src_b      = cfsm__alu_src_b;
  assign id_to_ex.result_src     = cfsm__result_src;
  assign id_to_ex.branch         = cfsm__branch;
  assign id_to_ex.jump           = cfsm__jump;
  assign id_to_ex.pc_target_kind = cfsm__pc_target_kind;
  assign id_to_ex.mem_write      = cfsm__mem_write;
  assign id_to_ex.reg_write      = cfsm__reg_write;
  assign id_to_ex.alu_control    = alu_control;
  assign id_to_ex.funct3         = funct3;
  assign id_to_ex.csr_read_data  = csr_read_data;
  assign id_to_ex.rd1            = rd1_safe;
  assign id_to_ex.rd2            = rd2_safe;
  assign id_to_ex.rd             = rd;
  assign id_to_ex.rs1            = rs1;
  assign id_to_ex.rs2            = rs2;
  assign id_to_ex.imm_ext        = imm_ext;
  assign id_to_ex.pc_cur         = if_to_id.pc_cur;
  assign id_to_ex.pc_plus_4      = if_to_id.pc_plus_4;

endmodule
