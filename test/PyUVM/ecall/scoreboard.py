from pyuvm import uvm_component, uvm_tlm_analysis_fifo
from core.access import CoreAccess
from .constants import SENTINEL_ADDRESS, SENTINEL


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
