from pyuvm import uvm_sequence

from .transaction import ALUTransaction


class ALUSequence(uvm_sequence):
    def __init__(self, name="alu_sequence", vectors=None):
        super().__init__(name)
        self.vectors = vectors or self.default_vectors()

    @staticmethod
    def default_vectors():
        return [
            (0, 0, control) for control in ALUTransaction.CONTROLS
        ] + [
            (0xFFFF_FFFF, 1, 0),
            (0x8000_0000, 1, 1),
            (0x8000_0000, 1, 7),
            (0x8000_0000, 1, 3),
            (0xFFFF_FFFF, 1, 4),
            (0x1234_5678, 4, 2),
            (0x8000_0000, 4, 6),
        ]

    async def body(self):
        for a, b, control in self.vectors:
            transaction = ALUTransaction()
            transaction.a = a
            transaction.b = b
            transaction.alu_control = control
            await self.start_item(transaction)
            await self.finish_item(transaction)
