from pyuvm import uvm_sequence


class OneProgramSequence(uvm_sequence):
    def __init__(self, program):
        super().__init__("program_sequence")
        self.program = program

    async def body(self):
        await self.start_item(self.program)
        await self.finish_item(self.program)
