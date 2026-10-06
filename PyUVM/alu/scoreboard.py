from pyuvm import uvm_scoreboard, uvm_tlm_analysis_fifo

from .reference_model import predict


class ALUScoreboard(uvm_scoreboard):
    def build_phase(self):
        self.fifo = uvm_tlm_analysis_fifo("fifo", self)
        self.analysis_export = self.fifo.analysis_export
        self.checked = 0

    async def run_phase(self):
        while True:
            transaction = await self.fifo.get()
            expected_result, expected_zero = predict(transaction)
            self.checked += 1
            assert transaction.result == expected_result, (
                f"ALU result mismatch: expected 0x{expected_result:08x}, "
                f"got 0x{transaction.result:08x}; {transaction}"
            )
            assert transaction.zero == expected_zero, (
                f"ALU zero mismatch: expected {expected_zero}, "
                f"got {transaction.zero}; {transaction}"
            )
