import cocotb
from cocotb.triggers import Timer
from pyuvm import test as pyuvm_test
from pyuvm import uvm_config_db, uvm_test

from PyUVM.alu.config import ALUConfig
from PyUVM.alu.environment import ALUEnvironment
from PyUVM.alu.sequence import ALUSequence


@pyuvm_test()
class ALUTest(uvm_test):
    def build_phase(self):
        config = ALUConfig(cocotb.top)
        uvm_config_db().set(self, "*", "alu_config", config)
        self.environment = ALUEnvironment("environment", self)

    async def run_phase(self):
        self.raise_objection()
        sequence = ALUSequence()
        await sequence.start(self.environment.agent.sequencer)
        await Timer(2, unit="ns")
        self.drop_objection()
