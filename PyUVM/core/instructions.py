"""Small RV32 instruction encoders shared by directed and randomized tests."""

XLEN_MASK = 0xFFFF_FFFF
NOP = 0x0000_0013
ECALL = 0x0000_0073
SPIN = 0x0000_006F  # jal x0, 0


def encode_add(rd, rs1, rs2):
    return (rs2 << 20) | (rs1 << 15) | (rd << 7) | 0x33


def encode_addi(rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def encode_csr(address, rd, funct3, rs1):
    return (address << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x73


def encode_sw(rs2, rs1, offset):
    imm = offset & 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 31) << 7) | 0x23


def encode_jal(rd, offset):
    assert offset % 2 == 0 and -(1 << 20) <= offset < (1 << 20)
    imm = offset & 0x1F_FFFF
    return (
        (((imm >> 20) & 1) << 31)
        | (((imm >> 1) & 0x3FF) << 21)
        | (((imm >> 11) & 1) << 20)
        | (((imm >> 12) & 0xFF) << 12)
        | (rd << 7)
        | 0x6F
    )


def disassemble(word, pc=0):
    """Format the instruction subset used by these tests; preserve unknown words."""
    def signed(value, bits):
        return value - (1 << bits) if value & (1 << (bits - 1)) else value

    if word == NOP:
        return "nop"
    if word == ECALL:
        return "ecall"
    opcode, funct3 = word & 0x7F, (word >> 12) & 7
    rd, rs1, rs2 = (word >> 7) & 31, (word >> 15) & 31, (word >> 20) & 31
    if opcode == 0x13 and funct3 == 0:
        return f"addi x{rd}, x{rs1}, {signed(word >> 20, 12)}"
    if opcode == 0x33 and funct3 == 0 and word >> 25 == 0:
        return f"add x{rd}, x{rs1}, x{rs2}"
    if opcode == 0x23 and funct3 == 2:
        offset = signed(((word >> 25) << 5) | ((word >> 7) & 31), 12)
        return f"sw x{rs2}, {offset}(x{rs1})"
    if opcode == 0x73 and funct3 in (1, 2, 3, 5, 6, 7):
        op = {1: "csrrw", 2: "csrrs", 3: "csrrc", 5: "csrrwi", 6: "csrrsi", 7: "csrrci"}[funct3]
        address = word >> 20
        csr = {0x305: "mtvec", 0x341: "mepc", 0x342: "mcause"}.get(address, f"0x{address:03x}")
        operand = str(rs1) if funct3 & 4 else f"x{rs1}"
        return f"{op} x{rd}, {csr}, {operand}"
    if opcode == 0x6F:
        offset = (((word >> 31) & 1) << 20) | (((word >> 21) & 0x3FF) << 1) \
            | (((word >> 20) & 1) << 11) | (((word >> 12) & 0xFF) << 12)
        target = (pc + signed(offset, 21)) & XLEN_MASK
        return f"jal x{rd}, 0x{target:08x}"
    return f".word 0x{word:08x}"
