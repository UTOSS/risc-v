`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/b/types.svh"

// Zba instructions used to decode into B_ALU_CTRL__SH*ADD and then fall through
// every sub-ALU, so the datapath returned 0. This checks the control -> zba_inst
// mapping and the result the ALU produces for the three instructions.
module zba_select_tb;

  import ext__b__types::*;

  logic [2:0] funct3;
  logic [6:0] funct7;
  opcode_t opcode;
  reg_t rd, rs2;
  b_alu_control_t control;
  logic [1:0] inst;
  logic [31:0] a, b, out;

  int errors = 0;

  ext__b__decoder dut_decoder
    ( .funct3        ( funct3        )
    , .funct7        ( funct7        )
    , .opcode        ( opcode        )
    , .rd            ( rd            )
    , .rs2           ( rs2           )
    , .b_alu_control ( control       )
    );

  zba dut_zba
    ( .reg1   ( a     )
    , .reg2   ( b     )
    , .inst   ( inst  )
    , .funct3 ( 3'b000 )
    , .funct7 ( 7'b0000000 )
    , .out    ( out   )
    );

  assign inst = zba_inst(control);

  task automatic check(input [2:0] f3, input [31:0] expected, input b_alu_control_t want,
                       input string name);
    funct3 = f3;
    #1;
    if (control !== want) begin
      $error("[FAIL] %s: control %0d, expected %0d", name, control, want);
      errors++;
    end else if (out !== expected) begin
      $error("[FAIL] %s: out %h, expected %h", name, out, expected);
      errors++;
    end else begin
      $display("[PASS] %s: control=%0d out=%h", name, control, out);
    end
  endtask

  initial begin
    // opcode/funct7 for the Zba encodings; rs2 = x2
    opcode = OPCODE_OP;
    funct7 = 7'b0010000;
    rs2    = 5'd2;
    rd     = 5'd3;
    a      = 32'd5;
    b      = 32'd7;

    check(3'b010, 32'd17, B_ALU_CTRL__SH1ADD, "sh1add");
    check(3'b100, 32'd27, B_ALU_CTRL__SH2ADD, "sh2add");
    check(3'b110, 32'd47, B_ALU_CTRL__SH3ADD, "sh3add");

    // a control that zba does not implement must leave its output at 0
    control = B_ALU_CTRL__ANDN;
    #1;
    if (out !== '0) begin
      $error("[FAIL] non-Zba control produced %h", out);
      errors++;
    end else begin
      $display("[PASS] zba idle for non-Zba control");
    end

    if (errors == 0)
      $display("\n=== ALL TESTS PASSED ===");
    else
      $display("\n=== %0d TEST(S) FAILED ===", errors);

    $finish;
  end

endmodule
