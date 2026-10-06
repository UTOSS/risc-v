from pyuvm import uvm_sequence_item


class ALUTransaction(uvm_sequence_item):
    """Inputs and sampled outputs at the ALU interface."""

    CONTROLS = tuple(range(10))

    def __init__(self, name="alu_transaction"):
        super().__init__(name)
        self.a = 0
        self.b = 0
        self.alu_control = 0
        self.result = None
        self.zero = None

    def clone(self):
        copy = ALUTransaction(self.get_name())
        copy.a = self.a
        copy.b = self.b
        copy.alu_control = self.alu_control
        copy.result = self.result
        copy.zero = self.zero
        return copy

    def __str__(self):
        return (
            f"a=0x{self.a:08x} b=0x{self.b:08x} "
            f"control={self.alu_control} result={self.result!r} zero={self.zero!r}"
        )
