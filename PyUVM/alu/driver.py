from cocotb.triggers import Timer
from pyuvm import uvm_driver, uvm_config_db


class ALUDriver(uvm_driver):
    def build_phase(self):
        self.config = uvm_config_db().get(self, "", "alu_config")

    async def run_phase(self):
        while True:
            transaction = await self.seq_item_port.get_next_item()
            dut = self.config.dut
            dut.a.value = transaction.a
            dut.b.value = transaction.b
            dut.alu_control.value = transaction.alu_control
            await Timer(self.config.sample_delay_ns, units="ns")
            self.seq_item_port.item_done()
