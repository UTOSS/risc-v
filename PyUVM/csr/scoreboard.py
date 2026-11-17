from pyuvm import uvm_component, uvm_tlm_analysis_fifo
from core.access import CoreAccess


class CSRScoreboard(uvm_component):
    def build_phase(self):
        for name in ("program", "writes", "csr_writes", "hw_writes", "pipeline"):
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
        self.require(len(programs) == 1, f"expected one CSR program, got {len(programs)}")
        if len(programs) != 1:
            return
        program = programs[0]
        writes, csr_writes, hw_writes, pipeline = (
            self.drain(fifo) for fifo in (self.writes, self.csr_writes, self.hw_writes, self.pipeline))
        self.require(program.completed,
                     f"CSR completion timeout after {program.elapsed_cycles} cycles")
        self.require(writes == program.expected_writes,
                     f"register writes: expected {program.expected_writes}, observed {writes}")
        self.require(csr_writes == program.expected_csr_writes,
                     f"software CSR writes: expected {program.expected_csr_writes}, observed {csr_writes}")
        self.require(hw_writes == program.expected_hw_writes,
                     f"hardware CSR writes: expected {program.expected_hw_writes}, observed {hw_writes}")
        self.require(bool(pipeline), "pipeline monitor observed no execution cycles")
        csr_stalls = sum(bool(sample[1]) for sample in pipeline)
        if program.expected_pipeline == "csr_stall":
            self.require(csr_stalls > 0, "adjacent CSR dependencies produced no decode stalls")
            self.require(all(sample[0] == sample[1] for sample in pipeline),
                         "fetch/decode stall controls diverged during CSR program")
        self.logger.info(f"Observed {len(pipeline)} pipeline cycles, {csr_stalls} decode-stall cycles")

    def report_phase(self):
        assert not self.errors, "\n".join(self.errors)
        self.logger.info("PASS: CSR read/modify/write, masks, write intent and architectural results")
