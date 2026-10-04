"""Reusable core access, program execution and architectural observation.

Tests load memory through the simulation top's backdoor. Architectural results are
observed at stable write ports before the rising edge that commits them.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, Timer
from pyuvm import uvm_analysis_port, uvm_component, uvm_driver, uvm_sequence_item

from instructions import NOP


class CoreAccess:
    """Keep simulation-top hierarchy knowledge in one place."""

    def __init__(self):
        self.dut = cocotb.top
        self.core = self.dut.core
        self.memory = self.dut.u_memory.M
        self.regfile = self.core.u_decode_stage.RegFile

    @staticmethod
    async def start_clock():
        dut = cocotb.top
        dut.reset.value = 1
        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
        await ClockCycles(dut.clk, 2)

    async def load(self, words, registers=None, fill_words=None):
        """Load word-indexed memory under reset; release away from the active edge."""
        await FallingEdge(self.dut.clk)
        self.dut.reset.value = 1
        count = len(self.memory) if fill_words is None else fill_words
        assert all(0 <= word < count for word in words), "program outside initialized memory"
        for word in range(count):
            self.memory[word].value = NOP
        for word, value in words.items():
            self.memory[word].value = value
        # Drain all pipeline stages, not just the register file reset.
        await ClockCycles(self.dut.clk, 8)
        await FallingEdge(self.dut.clk)
        self.dut.reset.value = 0
        for reg, value in (registers or {}).items():
            assert 0 < reg < 32
            self.regfile.RFMem[reg].value = value

    def register_write(self):
        rf = self.regfile
        if int(rf.regWrite.value) and int(rf.Addr3.value):
            return int(rf.Addr3.value), int(rf.dataIn.value)
        return None


class RegisterWriteMonitor(uvm_component):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        access = CoreAccess()
        while True:
            await FallingEdge(access.dut.clk)
            await ReadOnly()
            if not int(access.dut.reset.value):
                write = access.register_write()
                if write is not None:
                    self.ap.write(write)


class MemoryWriteMonitor(uvm_component):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        access = CoreAccess()
        bus = access.dut.d_bus
        while True:
            await FallingEdge(access.dut.clk)
            await ReadOnly()
            mask = int(bus.write_enable.value)
            if not int(access.dut.reset.value) and mask:
                self.ap.write((int(bus.address.value), mask, int(bus.write_data.value)))


class ProgramItem(uvm_sequence_item):
    """One reset-isolated program, with a completion marker and bounded runtime."""

    def __init__(self, name="program"):
        super().__init__(name)
        self.words = {}
        self.registers = {}
        self.completion = (31, 1)
        self.timeout_cycles = 160
        self.drain_cycles = 12
        self.completed = False
        self.elapsed_cycles = 0


class ProgramDriver(uvm_driver):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        access = CoreAccess()
        while True:
            item = await self.seq_item_port.get_next_item()
            await access.load(item.words, item.registers)
            self.ap.write(item)
            remaining = None
            for cycle in range(item.timeout_cycles + item.drain_cycles):
                await FallingEdge(access.dut.clk)
                await ReadOnly()
                item.elapsed_cycles = cycle + 1
                if remaining is not None:
                    remaining -= 1
                    if remaining == 0:
                        break
                elif access.register_write() == item.completion:
                    item.completed = True
                    remaining = item.drain_cycles
                elif cycle + 1 >= item.timeout_cycles:
                    break
            # Leave read-only phase before a following sequence starts another reset.
            await Timer(1, units="ns")
            self.seq_item_port.item_done()
