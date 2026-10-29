from pyuvm import uvm_config_db, uvm_env

from .agent import ALUAgent
from .coverage import ALUCoverage
from .scoreboard import ALUScoreboard


class ALUEnvironment(uvm_env):
    def build_phase(self):
        self.config = uvm_config_db().get(self, "", "alu_config")
        uvm_config_db().set(self, "agent", "alu_config", self.config)
        self.agent = ALUAgent("agent", self)
        self.scoreboard = ALUScoreboard("scoreboard", self)
        self.coverage = ALUCoverage("coverage", self)

    def connect_phase(self):
        self.agent.monitor.analysis_port.connect(self.scoreboard.analysis_export)
        self.agent.monitor.analysis_port.connect(self.coverage.analysis_export)
