"""Independent architectural model for the implemented machine CSRs."""

from .constants import CSR


class CSRReferenceModel:
    def __init__(self):
        self.values = {address: reset for address, (reset, _) in CSR.items()}
        self.register_writes = []
        self.csr_writes = []

    def execute(self, address, op, rd, operand, write_intent):
        old = self.values.get(address, 0)
        if rd:
            self.register_writes.append((rd, old))
        if write_intent:
            raw = operand if op == "write" else (
                old | operand if op == "set" else old & (~operand & 0xFFFFFFFF))
            # The monitor observes the writeback request before each CSR plugin applies WARL masks.
            self.csr_writes.append((address, raw))
            mask = CSR.get(address, (0, 0))[1]
            new = (raw & mask) | (old & (~mask & 0xFFFFFFFF))
            if address in CSR:
                self.values[address] = new
