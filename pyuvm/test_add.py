"""Minimal pyuvm testbench: randomized `add` / `addi` instructions checked against a reference model.

Each randomized item is one arithmetic instruction with random source registers, destination register
and operand values. The driver runs it on the core (the `top` of envs/simulation, i.e. the core plus
its memory): it resets the core, loads the instruction into memory and the operands into the register
file (both backdoor), and lets it run. The monitor independently watches the register file write
port, and the scoreboard compares every write against the reference model.
"""

import os
import random

import cocotb
from cocotb.triggers import ClockCycles
from pyuvm import (
    ConfigDB,
    uvm_analysis_port,
    uvm_component,
    uvm_driver,
    uvm_env,
    uvm_sequence,
    uvm_sequence_item,
    uvm_sequencer,
    uvm_test,
    uvm_tlm_analysis_fifo,
)
import pyuvm

from core_tb import CoreAccess, RegisterWriteMonitor
from instructions import XLEN_MASK, encode_add, encode_addi

# memory word the instruction under test is placed at; the preceding nops leave time for the backdoor
# register file writes after reset is released, before the instruction reaches decode
INSTRUCTION_WORD = 3
PROGRAM_WORDS = 16
CYCLES_PER_ITEM = 20

# values that tend to expose adder bugs (carries across the whole word, overflow, sign)
CORNER_VALUES = [0x0000_0000, 0x0000_0001, 0x7FFF_FFFF, 0x8000_0000, 0xFFFF_FFFF]
CORNER_IMMEDIATES = [0, 1, -1, 2047, -2048]


# ---------------------------------------------------------------------------------------------------
# Sequence item & sequence
# ---------------------------------------------------------------------------------------------------


class AddItem(uvm_sequence_item):
    """One `add rd, rs1, rs2` or `addi rd, rs1, imm`, with the initial values of its source registers"""

    def __init__(self, name="add_item"):
        super().__init__(name)
        self.op = "add"
        self.rd = 1
        self.rs1 = 1
        self.rs2 = 2
        self.rs1_value = 0
        self.rs2_value = 0
        self.imm = 0

    def randomize(self):
        self.op = random.choice(["add", "addi"])
        # x0 is hardwired to zero, so only use x1..x31; the two sources must differ since each gets
        # its own initial value
        self.rs1, self.rs2 = random.sample(range(1, 32), 2)
        self.rd = random.randint(1, 31)
        self.rs1_value = self._random_value()
        self.rs2_value = self._random_value()
        self.imm = (
            random.choice(CORNER_IMMEDIATES) if random.random() < 0.25 else random.randint(-2048, 2047)
        )

    @staticmethod
    def _random_value():
        return random.choice(CORNER_VALUES) if random.random() < 0.25 else random.getrandbits(32)

    def encode(self):
        if self.op == "add":
            return encode_add(self.rd, self.rs1, self.rs2)
        return encode_addi(self.rd, self.rs1, self.imm)

    def expected(self):
        """Reference model: (destination register, value written to it)"""
        if self.op == "add":
            return self.rd, (self.rs1_value + self.rs2_value) & XLEN_MASK
        return self.rd, (self.rs1_value + self.imm) & XLEN_MASK

    def __str__(self):
        if self.op == "add":
            return (
                f"add x{self.rd}, x{self.rs1}, x{self.rs2}"
                f" (x{self.rs1}={self.rs1_value:#010x}, x{self.rs2}={self.rs2_value:#010x})"
            )
        return f"addi x{self.rd}, x{self.rs1}, {self.imm} (x{self.rs1}={self.rs1_value:#010x})"


class RandomAddSequence(uvm_sequence):
    async def body(self):
        for _ in range(ConfigDB().get(None, "", "NUM_ITEMS")):
            item = AddItem()
            await self.start_item(item)
            item.randomize()
            await self.finish_item(item)


# ---------------------------------------------------------------------------------------------------
# Driver, monitor, scoreboard
# ---------------------------------------------------------------------------------------------------


class CoreDriver(uvm_driver):
    """Runs every item on the core and publishes it as the stimulus to be checked"""

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    def start_of_simulation_phase(self):
        self.dut = cocotb.top

    async def run_phase(self):
        access = CoreAccess()
        while True:
            item = await self.seq_item_port.get_next_item()
            self.logger.info(f"driving {item}")
            await access.load(
                {INSTRUCTION_WORD: item.encode()},
                {item.rs1: item.rs1_value, item.rs2: item.rs2_value},
                fill_words=PROGRAM_WORDS,
            )

            self.ap.write(item)
            await ClockCycles(self.dut.clk, CYCLES_PER_ITEM)

            self.seq_item_port.item_done()


class Scoreboard(uvm_component):
    """Compares every register write seen by the monitor against the reference model of each item"""

    def build_phase(self):
        self.stimulus_fifo = uvm_tlm_analysis_fifo("stimulus_fifo", self)
        self.writes_fifo = uvm_tlm_analysis_fifo("writes_fifo", self)
        self.stimulus_export = self.stimulus_fifo.analysis_export
        self.writes_export = self.writes_fifo.analysis_export
        self.passed = 0
        self.failed = 0

    def check_phase(self):
        while True:
            got_item, item = self.stimulus_fifo.try_get()
            if not got_item:
                break

            expected_rd, expected_value = item.expected()
            got_write, write = self.writes_fifo.try_get()
            if not got_write:
                self.logger.error(f"FAIL {item}: expected x{expected_rd} = {expected_value:#010x}, no write")
                self.failed += 1
                continue

            rd, value = write
            if (rd, value) == (expected_rd, expected_value):
                self.logger.info(f"PASS {item}: x{rd} = {value:#010x}")
                self.passed += 1
            else:
                self.logger.error(
                    f"FAIL {item}: expected x{expected_rd} = {expected_value:#010x}, got x{rd} = {value:#010x}"
                )
                self.failed += 1

        while True:
            got_write, write = self.writes_fifo.try_get()
            if not got_write:
                break
            rd, value = write
            self.logger.error(f"FAIL unexpected write x{rd} = {value:#010x}")
            self.failed += 1

    def report_phase(self):
        self.logger.info(f"{self.passed} passed, {self.failed} failed")
        assert self.failed == 0, f"{self.failed} of {self.passed + self.failed} checks failed"
        assert self.passed > 0, "nothing was checked"


# ---------------------------------------------------------------------------------------------------
# Environment & test
# ---------------------------------------------------------------------------------------------------


class AddEnv(uvm_env):
    def build_phase(self):
        self.sequencer = uvm_sequencer("sequencer", self)
        self.driver = CoreDriver("driver", self)
        self.monitor = RegisterWriteMonitor("monitor", self)
        self.scoreboard = Scoreboard("scoreboard", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
        self.driver.ap.connect(self.scoreboard.stimulus_export)
        self.monitor.ap.connect(self.scoreboard.writes_export)


@pyuvm.test()
class RandomAddTest(uvm_test):
    """Randomized `add` / `addi`, `NUM_ITEMS` of them (default 20)"""

    def build_phase(self):
        ConfigDB().set(None, "*", "NUM_ITEMS", int(os.environ.get("NUM_ITEMS", "20")))
        self.env = AddEnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        self.logger.info(f"random seed {cocotb.RANDOM_SEED} (rerun with RANDOM_SEED={cocotb.RANDOM_SEED})")

        await CoreAccess.start_clock()

        await RandomAddSequence("seq").start(self.env.sequencer)
        self.drop_objection()
