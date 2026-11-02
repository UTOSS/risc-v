"""Directed full-core CSR test, driven by real encoded instructions."""

import os
import cocotb
from pyuvm import uvm_test, uvm_root
from core.access import CoreAccess
from csr.environment import CSREnv
from csr.program import CSRProgram
from csr.sequence import OneCSRProgramSequence


class CSRDirectedTest(uvm_test):
    def build_phase(self):
        assert "Zicsr" in os.environ.get("UTOSS_RISCV_CONFIG", ""), \
            "CSR tests require UTOSS_RISCV_CONFIG=RV32IZicsr (or another Zicsr configuration)"
        self.env = CSREnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        await CoreAccess.start_clock()
        program = CSRProgram()
        program.log_listing(self.logger)
        await OneCSRProgramSequence(program).start(self.env.sequencer)
        self.drop_objection()


@cocotb.test()
async def test_csr_directed(dut):
    await uvm_root().run_test(CSRDirectedTest)
