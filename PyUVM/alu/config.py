from dataclasses import dataclass


@dataclass
class ALUConfig:
    """Configuration passed through uvm_config_db at the agent boundary."""

    dut: object
    active: bool = True
    sample_delay_ns: int = 1
