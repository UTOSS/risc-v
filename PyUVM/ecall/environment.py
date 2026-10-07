from pyuvm import uvm_env, uvm_sequencer
from core.access import ProgramDriver, RegisterWriteMonitor, MemoryWriteMonitor
from .monitor import TrapMonitor
from .scoreboard import EcallScoreboard


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
