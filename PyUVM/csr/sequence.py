from pyuvm import uvm_sequence


class OneCSRProgramSequence(uvm_sequence):
    def __init__(self, program):
        super().__init__("csr_program_sequence")
        self.program = program

    async def body(self):
        await self.start_item(self.program)
        await self.finish_item(self.program)
