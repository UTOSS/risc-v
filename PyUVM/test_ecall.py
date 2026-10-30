"""Directed full-core ECALL tests; requires a Zicsr configuration."""

import os
import cocotb
from pyuvm import uvm_test, uvm_root
from core.access import CoreAccess
from ecall.environment import EcallEnv
from ecall.program import EcallProgram
from ecall.sequence import OneProgramSequence


class EcallTestBase(uvm_test):
    mode = "trap"
    padding = 8
    handler = 0x100

    def build_phase(self):
        assert "Zicsr" in os.environ.get("UTOSS_RISCV_CONFIG", ""), \
            "ECALL tests require UTOSS_RISCV_CONFIG=RV32IZicsr (or another Zicsr configuration)"
        self.env = EcallEnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        await CoreAccess.start_clock()
        program = EcallProgram(padding=self.padding, handler=self.handler, mode=self.mode)
        self.logger.info(f"mode={self.mode}, test site={program.ecall_pc:#x}, handler={self.handler:#x}")
        program.log_listing(self.logger)
        await OneProgramSequence(program).start(self.env.sequencer)
        self.drop_objection()



class EcallSmokeTest(EcallTestBase):
    pass



class EcallRelocatedTest(EcallTestBase):
    padding = 13
    handler = 0x180



class EcallWrongPathTest(EcallTestBase):
    mode = "wrong_path"



class EcallDecodeNegativeTest(EcallTestBase):
    mode = "decode_negative"



@cocotb.test()
async def test_ecall_smoke(dut):
    await uvm_root().run_test(EcallSmokeTest)


@cocotb.test()
async def test_ecall_relocated(dut):
    await uvm_root().run_test(EcallRelocatedTest)


@cocotb.test()
async def test_ecall_wrong_path(dut):
    await uvm_root().run_test(EcallWrongPathTest)


@cocotb.test()
async def test_ecall_decode_negative(dut):
    await uvm_root().run_test(EcallDecodeNegativeTest)
