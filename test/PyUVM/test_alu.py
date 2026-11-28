import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_config_db, uvm_root, uvm_test

from alu.config import ALUConfig
from alu.environment import ALUEnvironment
from alu.sequence import ALUSequence


class ALUTest(uvm_test):
    def build_phase(self):
        config = ALUConfig(cocotb.top)
        uvm_config_db().set(self, "*", "alu_config", config)
        self.environment = ALUEnvironment("environment", self)

    async def run_phase(self):
        self.raise_objection()
        sequence = ALUSequence()
        await sequence.start(self.environment.agent.sequencer)
        await Timer(2, units="ns")
        self.drop_objection()


@cocotb.test()
async def test_alu(dut):
    # Avoid pyuvm.test's stack-based module lookup, which can fail when cached
    # Python filenames and checkout paths differ in case.
    await uvm_root().run_test(ALUTest)
