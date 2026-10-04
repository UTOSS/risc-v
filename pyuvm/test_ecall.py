"""Directed ECALL programs on the same simulation top as the ADD tests."""

import os

from cocotb.triggers import FallingEdge, ReadOnly
import pyuvm
from pyuvm import (
    uvm_analysis_port, uvm_component, uvm_env, uvm_sequence, uvm_sequencer,
    uvm_test, uvm_tlm_analysis_fifo,
)

from core_tb import CoreAccess, MemoryWriteMonitor, ProgramDriver, ProgramItem, RegisterWriteMonitor
from instructions import ECALL, NOP, SPIN, encode_addi, encode_csr, encode_jal, encode_sw, disassemble

MTVEC, MEPC, MCAUSE = 0x305, 0x341, 0x342
PC_SRC_MTVEC = 2
SENTINEL_ADDRESS = 0x300
SENTINEL = 0xA5A5_5A5A


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



class TrapMonitor(uvm_component):
    """Observe trap hardware independently of stimulus and software readback."""

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        access = CoreAccess()
        core = access.core
        mepc, mcause = core.mepc_hw_request, core.mcause_hw_request
        while True:
            await FallingEdge(access.dut.clk)
            await ReadOnly()
            if int(access.dut.reset.value):
                continue
            epc_enable = int(mepc.write_enable.value)
            cause_enable = int(mcause.write_enable.value)
            pc_src = int(core.u_execute_stage.pc_src.value)
            if epc_enable or cause_enable or pc_src == PC_SRC_MTVEC:
                self.ap.write((epc_enable, int(mepc.write_data.value),
                               cause_enable, int(mcause.write_data.value), pc_src,
                               int(core.mtvec_hw_request.read_data.value),
                               int(core.u_fetch_stage.pc_next.value)))


class EcallScoreboard(uvm_component):
    """One program per test: compare complete event streams, including extra events."""

    def build_phase(self):
        for name in ("program", "writes", "stores", "traps"):
            setattr(self, name, uvm_tlm_analysis_fifo(name, self))
        self.errors = []

    @staticmethod
    def drain(fifo):
        items = []
        while True:
            ok, item = fifo.try_get()
            if not ok:
                return items
            items.append(item)

    def require(self, condition, message):
        if not condition:
            self.errors.append(message)
            self.logger.error(message)

    def check_phase(self):
        programs = self.drain(self.program)
        self.require(len(programs) == 1, f"expected one program, got {len(programs)}")
        if len(programs) != 1:
            return
        program = programs[0]
        writes, stores, traps = (self.drain(fifo) for fifo in (self.writes, self.stores, self.traps))
        self.require(program.completed,
                     f"completion timeout after {program.elapsed_cycles} cycles; handler={program.handler:#x}")
        self.require(writes == program.expected_writes,
                     f"register writes: expected {program.expected_writes}, observed {writes}")
        self.require(not stores, f"unexpected memory stores (address, mask, data): {stores}")
        self.require(traps == program.expected_traps,
                     f"trap events: expected {program.expected_traps}, observed {traps}")
        sentinel = int(CoreAccess().memory[SENTINEL_ADDRESS // 4].value)
        self.require(sentinel == SENTINEL, f"wrong-path store changed sentinel to {sentinel:#x}")

    def report_phase(self):
        assert not self.errors, "\n".join(self.errors)
        self.logger.info("PASS: program results, trap events, flush side effects and completion")


class EcallEnv(uvm_env):
    def build_phase(self):
        self.sequencer = uvm_sequencer("sequencer", self)
        self.driver = ProgramDriver("driver", self)
        self.writes = RegisterWriteMonitor("writes", self)
        self.stores = MemoryWriteMonitor("stores", self)
        self.traps = TrapMonitor("traps", self)
        self.scoreboard = EcallScoreboard("scoreboard", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
        self.driver.ap.connect(self.scoreboard.program.analysis_export)
        for name in ("writes", "stores", "traps"):
            getattr(self, name).ap.connect(getattr(self.scoreboard, name).analysis_export)


class OneProgramSequence(uvm_sequence):
    def __init__(self, program):
        super().__init__("program_sequence")
        self.program = program

    async def body(self):
        await self.start_item(self.program)
        await self.finish_item(self.program)


class EcallTestBase(uvm_test):
    mode = "trap"
    padding = 8
    handler = 0x100

    def build_phase(self):
        assert "Zicsr" in os.environ.get("UTOSS_RISCV_CONFIG", ""), \
            "ECALL tests require UTOSS_RISCV_CONFIG=RV32IZicsr (or another Zicsr configuration)"
        self.env = EcallEnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        await CoreAccess.start_clock()
        program = EcallProgram(padding=self.padding, handler=self.handler, mode=self.mode)
        self.logger.info(f"mode={self.mode}, test site={program.ecall_pc:#x}, handler={self.handler:#x}")
        program.log_listing(self.logger)
        await OneProgramSequence(program).start(self.env.sequencer)
        self.drop_objection()


@pyuvm.test()
class EcallSmokeTest(EcallTestBase):
    pass


@pyuvm.test()
class EcallRelocatedTest(EcallTestBase):
    padding = 13
    handler = 0x180


@pyuvm.test()
class EcallWrongPathTest(EcallTestBase):
    mode = "wrong_path"


@pyuvm.test()
class EcallDecodeNegativeTest(EcallTestBase):
    mode = "decode_negative"
