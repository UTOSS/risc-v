from core.access import ProgramItem
from core.instructions import ECALL, NOP, SPIN, encode_addi, encode_csr, encode_jal, encode_sw, disassemble
from .constants import MTVEC, MEPC, MCAUSE, PC_SRC_MTVEC, SENTINEL_ADDRESS, SENTINEL


class EcallProgram(ProgramItem):
    def __init__(self, name="ecall", padding=8, handler=0x100, mode="trap"):
        super().__init__(name)
        self.mode = mode
        self.handler = handler
        self.words = {SENTINEL_ADDRESS // 4: SENTINEL}
        code = [NOP] * 3
        code += [encode_addi(1, 0, handler), encode_csr(MTVEC, 0, 1, 1)]
        code += [NOP] * padding  # baseline isolates trap handling from pending mtvec writes
        code += [encode_addi(5, 0, 0x55)]  # an older write must survive the redirect
        self.ecall_pc = len(code) * 4
        self.expected_writes = [(1, handler), (5, 0x55)]
        self.expected_traps = []
        if mode == "trap":
            code += [ECALL, encode_sw(5, 0, SENTINEL_ADDRESS), encode_addi(6, 0, 0x66),
                     encode_csr(MEPC, 0, 1, 5), SPIN]
            # Both enables, saved PC/cause, EX selector, hardware read and fetch target.
            self.expected_traps = [(1, self.ecall_pc, 1, 11, PC_SRC_MTVEC, handler, handler)]
            self.expected_writes += [(10, self.ecall_pc), (11, 11), self.completion]
        elif mode == "wrong_path":
            # ECALL and side effects fetched behind a taken jump must be discarded.
            code += [encode_jal(0, 16), ECALL, encode_sw(5, 0, SENTINEL_ADDRESS),
                     encode_addi(6, 0, 0x66), encode_addi(31, 0, 1), SPIN]
            self.expected_writes += [self.completion]
        elif mode == "decode_negative":
            # CSR address zero is unimplemented, but this legal CSR instruction is not ECALL.
            code += [encode_csr(0, 7, 2, 0), encode_addi(31, 0, 1), SPIN]
            self.expected_writes += [(7, 0), self.completion]
        else:
            raise ValueError(mode)
        assert len(code) * 4 < handler < SENTINEL_ADDRESS - 32
        self.main_words = len(code)
        self.words.update(enumerate(code))
        handler_code = [encode_csr(MEPC, 10, 2, 0), encode_csr(MCAUSE, 11, 2, 0),
                        encode_addi(31, 0, 1), SPIN]
        self.words.update({handler // 4 + i: word for i, word in enumerate(handler_code)})
        self.handler_words = len(handler_code)

    def log_listing(self, logger):
        """Log the loaded image, including instructions expected to be flushed."""
        logger.info("Assembly listing of loaded program (not a retirement trace):")
        site_label = {"trap": "ecall_site", "wrong_path": "taken_jump",
                      "decode_negative": "non_ecall_csr"}[self.mode]
        labels = {0: "main", self.ecall_pc: site_label, self.handler: "handler"}
        if self.mode == "trap":
            labels[self.ecall_pc + 4] = "wrong_path (must be flushed)"
        elif self.mode == "wrong_path":
            labels[self.ecall_pc + 4] = "wrong_path_ecall (must be flushed)"
            labels[self.ecall_pc + 16] = "jump_target"
        for start, count in ((0, self.main_words), (self.handler, self.handler_words)):
            for pc in range(start, start + count * 4, 4):
                if pc in labels:
                    logger.info(f"{labels[pc]}:")
                word = self.words[pc // 4]
                logger.info(f"  {pc:08x}:  {word:08x}  {disassemble(word, pc)}")
        logger.info(f"  {SENTINEL_ADDRESS:08x}:  {SENTINEL:08x}  .word 0x{SENTINEL:08x}  # data sentinel")
        logger.info("Unlisted memory is initialized to nop.")
