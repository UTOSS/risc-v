from cocotb.triggers import FallingEdge, ReadOnly
from pyuvm import uvm_analysis_port, uvm_component
from core.access import CoreAccess
from .constants import PC_SRC_MTVEC


class TrapMonitor(uvm_component):
    """Observe trap hardware independently of stimulus and software readback."""

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        access = CoreAccess()
        core = access.core
        mepc, mcause = core.mepc_hw_request, core.mcause_hw_request
        while True:
            await FallingEdge(access.dut.clk)
            await ReadOnly()
            if int(access.dut.reset.value):
                continue
            epc_enable = int(mepc.write_enable.value)
            cause_enable = int(mcause.write_enable.value)
            pc_src = int(core.u_execute_stage.pc_src.value)
            if epc_enable or cause_enable or pc_src == PC_SRC_MTVEC:
                self.ap.write((epc_enable, int(mepc.write_data.value),
                               cause_enable, int(mcause.write_data.value), pc_src,
                               int(core.mtvec_hw_request.read_data.value),
                               int(core.u_fetch_stage.pc_next.value)))
