from cocotb.triggers import Timer
from pyuvm import uvm_config_db, uvm_monitor, uvm_analysis_port

from .transaction import ALUTransaction


class ALUMonitor(uvm_monitor):
    def build_phase(self):
        self.analysis_port = uvm_analysis_port("analysis_port", self)
        self.config = uvm_config_db().get(self, "", "alu_config")

    async def run_phase(self):
        while True:
            await Timer(self.config.sample_delay_ns, unit="ns")
            dut = self.config.dut
            transaction = ALUTransaction()
            transaction.a = int(dut.a.value)
            transaction.b = int(dut.b.value)
            transaction.alu_control = int(dut.alu_control.value)
            transaction.result = int(dut.out.value)
            transaction.zero = bool(dut.zeroE.value)
            self.analysis_port.write(transaction)
