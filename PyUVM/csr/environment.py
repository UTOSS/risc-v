from pyuvm import uvm_env, uvm_sequencer
from core.access import ProgramDriver, RegisterWriteMonitor
from .monitor import CSRWriteMonitor, CSRHardwareWriteMonitor, PipelineMonitor
from .scoreboard import CSRScoreboard


class CSREnv(uvm_env):
    def build_phase(self):
        self.sequencer = uvm_sequencer("sequencer", self)
        self.driver = ProgramDriver("driver", self)
        self.writes = RegisterWriteMonitor("writes", self)
        self.csr_writes = CSRWriteMonitor("csr_writes", self)
        self.hw_writes = CSRHardwareWriteMonitor("hw_writes", self)
        self.pipeline = PipelineMonitor("pipeline", self)
        self.scoreboard = CSRScoreboard("scoreboard", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
        self.driver.ap.connect(self.scoreboard.program.analysis_export)
        for name in ("writes", "csr_writes", "hw_writes", "pipeline"):
            getattr(self, name).ap.connect(getattr(self.scoreboard, name).analysis_export)
