`include "src/timescale.svh"

`include "test/utils.svh"

module c_extension_tb;

  logic [15:0] instr_c;
  logic [31:0] instr_out;
  logic is_illegal;

  logic [4:0] rd  = 5'b00001;
  logic [4:0] rs1 = 5'b00010;
  logic [4:0] rs2 = 5'b00100;

  logic [31:0] imm;

  ext__c__decoder uut
    ( .instr_c    ( instr_c    )
    , .instr_out  ( instr_out  )
    , .is_illegal ( is_illegal )
    );

  initial begin

    // C.LUI expands to lui rd, imm
    // C.LUI format: {funct3, imm[17], rd, imm[16:12], opcode}
    imm = {15'b0, 5'b10101, 12'b0};
    instr_c = {3'b011, imm[17], rd, imm[16:12], 2'b01};
    #10
    // LUI format: {imm[31:12], rd, opcode[6:0]}
    `assert_equal(instr_out, {imm[31:12], rd, 7'b0110111})
    `assert_equal(is_illegal, 1'b0)

    // Test C.LUI with sign extension
    imm = {15'b111111111111111, 5'b10101, 12'b0};
    instr_c = {3'b011, imm[17], rd, imm[16:12], 2'b01};
    #10
    // LUI format: {imm[31:12], rd, opcode[6:0]}
    `assert_equal(instr_out, {imm[31:12], rd, 7'b0110111})
    `assert_equal(is_illegal, 1'b0)

    // C.SLLI expands to slli rd, rd, shamt[5:0]
    // C.SLLI format: {funct3, shamt[5], rd, shamt[4:0], opcode}
    imm = {26'b0, 6'b001010};
    instr_c = {3'b000, imm[5], rd, imm[4:0], 2'b10};
    #10
    // SLLI format: {imm[11:0], rs1, funct3, rd, opcode}
    `assert_equal(instr_out, {imm[11:0], rd, 3'h1, rd, 7'b0010011})
    `assert_equal(is_illegal, 1'b0)

    // C.ADDI4SPN expands to addi rd', x2, nzuimm
    // C.ADDI4SPN format: {funct3, nzuimm[5:4], nzuimm[9:6], nzuimm[2], nzuimm[3], rd', opcode}
    imm = {22'b0, 8'b00101001, 2'b00};
    instr_c = {3'b000, imm[5:4], imm[9:6], imm[2], imm[3], rd[2:0], 2'b00};
    #10
    // ADDI format: {imm[11:0], rs1, funct3, rd, opcode}
    `assert_equal(instr_out, {imm[11:0], 5'b00010, 3'h0, {2'b01, rd[2:0]}, 7'b0010011})
    `assert_equal(is_illegal, 1'b0)

    // C.LW expands to lw rd', uimm(rs1')
    // C.LW format: {funct3, uimm[5:3], rs1', uimm[2], uimm[6], rd', opcode}
    imm = {25'b0, 5'b10101, 2'b00};
    instr_c = {3'b010, imm[5:3], rs1[2:0], imm[2], imm[6], rd[2:0], 2'b00};
    #10
    // LW format: {imm[11:0], rs1, funct3, rd, opcode}
    `assert_equal(instr_out, {imm[11:0], {2'b01, rs1[2:0]}, 3'h2, {2'b01, rd[2:0]}, 7'b0000011})
    `assert_equal(is_illegal, 1'b0)

    // C.SW expands to sw rs2', uimm(rs1')
    // C.SW format: {funct3, uimm[5:3], rs1', uimm[2], uimm[6], rs2', opcode}
    imm = {25'b0, 5'b11101, 2'b00};
    instr_c = {3'b110, imm[5:3], rs1[2:0], imm[2], imm[6], rs2[2:0], 2'b00};
    #10
    // SW format: {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode}
    `assert_equal(instr_out, {imm[11:5], {2'b01, rs2[2:0]}, {2'b01, rs1[2:0]}, 3'h2, imm[4:0], 7'b0100011})
    `assert_equal(is_illegal, 1'b0)

    // C.XOR expands to xor rd', rd', rs2'
    // C.XOR format: {funct6, rd'/rs1', funct2, rs2', opcode}
    instr_c = {6'b100011, rd[2:0], 2'b01, rs2[2:0], 2'b01};
    #10
    // XOR format: {funct7, rs2, rs1, funct3, rd, opcode}
    `assert_equal(instr_out, {7'b0000000, {2'b01, rs2[2:0]}, {2'b01, rd[2:0]}, 3'h4, {2'b01, rd[2:0]}, 7'b0110011})
    `assert_equal(is_illegal, 1'b0)

    // C.MV expands to add rd, x0, rs2
    // C.MV format: {funct3, 1'b0, rd, rs2, opcode}
    instr_c = {3'b100, 1'b0, rd, rs2, 2'b10};
    #10
    // ADD format: {funct7, rs2, rs1, funct3, rd, opcode}
    `assert_equal(instr_out, {7'b0000000, rs2, 5'b00000, 3'h0, rd, 7'b0110011})
    `assert_equal(is_illegal, 1'b0)

    // C.BEQZ expands to beq rs1', x0, offset
    // C.BEQZ format: {funct3, offset[8], offset[4:3], rs1', offset[7:6], offset[2:1], offset[5], opcode}
    imm = {19'b0, 12'b00000101011, 1'b0};
    instr_c = {3'b110, imm[8], imm[4:3], rs1[2:0], imm[7:6], imm[2:1], imm[5], 2'b01};
    #10
    // BEQ format: {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode}
    `assert_equal(instr_out, {imm[12], imm[10:5], 5'b00000, {2'b01, rs1[2:0]}, 3'h0, imm[4:1], imm[11], 7'b1100011})
    `assert_equal(is_illegal, 1'b0)

    // C.J expands to jal x0, offset
    // C.J format: {funct3, offset[11], offset[4], offset[9:8], offset[10], offset[6], offset[7], offset[3:1], offset[5], opcode}
    imm = {11'b0, 20'b0000000000101010101, 1'b0};
    instr_c = {3'b101, imm[11], imm[4], imm[9:8], imm[10], imm[6], imm[7], imm[3:1], imm[5], 2'b01};
    #10
    // JAL format: {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode}
    `assert_equal(instr_out, {imm[20], imm[10:1], imm[11], imm[19:12], 5'b00000, 7'b1101111})
    `assert_equal(is_illegal, 1'b0)

    // C.SWSP expands to sw rs2, uimm(x2)
    // C.SWSP format: {funct3, uimm[5:2], uimm[7:6], rs2, opcode}
    imm = {24'b0, 6'b010111, 2'b00};
    instr_c = {3'b110, imm[5:2], imm[7:6], rs2, 2'b10};
    #10
    // SW format: {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode}
    `assert_equal(instr_out, {imm[11:5], rs2, 5'b00010, 3'h2, imm[4:0], 7'b0100011})
    `assert_equal(is_illegal, 1'b0)

    // Illegal: C.ADDI4SPN with nzuimm = 0 is reserved
    imm = {32'b0};
    instr_c = {3'b000, imm[9:2], rd[2:0], 2'b00};
    #10
    `assert_equal(is_illegal, 1'b1)

    // Illegal: C.LWSP with rd = x0 is reserved
    imm = {24'b0, 6'b001011, 2'b00};
    instr_c = {3'b010, imm[5], 5'b00000, imm[4:2], imm[7:6], 2'b10};
    #10
    `assert_equal(is_illegal, 1'b1)

    // Illegal: C.JR with rs1 = x0 is reserved
    instr_c = {3'b100, 1'b0, 5'b00000, 5'b00000, 2'b10};
    #10
    `assert_equal(is_illegal, 1'b1)

    $finish;
  end

  wire _unused = &{rd, rs1, rs2, imm};

  `SETUP_VCD_DUMP(c_extension_tb)

endmodule
