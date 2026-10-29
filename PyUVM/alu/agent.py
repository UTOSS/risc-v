from pyuvm import uvm_agent, uvm_config_db

from .driver import ALUDriver
from .monitor import ALUMonitor
from .sequencer import ALUSequencer


class ALUAgent(uvm_agent):
    def build_phase(self):
        self.config = uvm_config_db().get(self, "", "alu_config")
        self.monitor = ALUMonitor("monitor", self)
        if self.config.active:
            self.sequencer = ALUSequencer("sequencer", self)
            self.driver = ALUDriver("driver", self)

    def connect_phase(self):
        if self.config.active:
            self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
