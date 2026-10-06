from pyuvm import uvm_sequencer

from .transaction import ALUTransaction


class ALUSequencer(uvm_sequencer):
    """Typed naming boundary for the ALU agent's standard PyUVM sequencer."""

    item_type = ALUTransaction
