"""Instruction-driven CSR test program and its independently predicted results."""

from core.access import ProgramItem
from core.instructions import NOP, SPIN, encode_addi, encode_csr, disassemble
from .constants import CSR, NAMES
from .reference_model import CSRReferenceModel


class CSRProgram(ProgramItem):
    def __init__(self, name="csr"):
        super().__init__(name)
        self.timeout_cycles = 240
        self.registers = {1: 0x13579BDF, 2: 0x0000000F, 3: 0x00000003,
                          4: 0x00000001, 5: 0x00000000}
        model = CSRReferenceModel()
        # The synchronous instruction memory needs the same priming slots as ECALL programs.
        code = [NOP, NOP, NOP]

        def csr(address, rd, funct3, rs1):
            code.append(encode_csr(address, rd, funct3, rs1))
            immediate = bool(funct3 & 4)
            source = rs1 if immediate else self.registers.get(rs1, 0)
            op = {1: "write", 2: "set", 3: "clear", 5: "write", 6: "set", 7: "clear"}[funct3]
            write_intent = op == "write" or rs1 != 0
            model.execute(address, op, rd, source, write_intent)

        # Register and immediate forms, x0 suppression, read-only and WARL masks.
        csr(0x340, 6, 1, 1)       # csrrw x6, mscratch, x1
        csr(0x340, 7, 2, 2)       # csrrs x7, mscratch, x2
        csr(0x340, 8, 3, 3)       # csrrc x8, mscratch, x3
        csr(0x340, 9, 2, 0)       # csrrs x9, mscratch, x0: read only
        csr(0x340, 10, 5, 5)      # csrrwi x10, mscratch, 0: still writes
        csr(0x340, 11, 6, 4)      # csrrsi x11, mscratch, 1
        csr(0x340, 12, 7, 2)      # csrrci x12, mscratch, 2
        csr(0x305, 13, 1, 1)      # mtvec alignment mask
        csr(0x305, 14, 2, 4)
        csr(0x341, 15, 1, 1)      # mepc bit-zero mask
        csr(0x342, 16, 1, 1)      # mcause implementation mask
        csr(0xF14, 17, 1, 1)      # write ignored by read-only mask
        csr(0xF14, 18, 2, 2)
        csr(0x7C0, 19, 1, 1)      # unimplemented CSR reads zero
        csr(0x7C0, 20, 2, 2)      # unimplemented CSR write has no state
        code += [encode_addi(31, 0, 1), SPIN]
        self.expected_writes = model.register_writes + [(31, 1)]
        self.expected_csr_writes = model.csr_writes
        self.expected_hw_writes = []
        self.expected_pipeline = "csr_stall"
        self.words = {index: word for index, word in enumerate(code)}
        self.words.update({0x300 // 4: NOP})

    def log_listing(self, logger):
        logger.info("CSR architectural reference model starts from specified reset values.")
        for index, word in sorted(self.words.items()):
            if index < 0x300 // 4:
                logger.info(f"  {index * 4:08x}: {word:08x}  {disassemble(word, index * 4)}")
