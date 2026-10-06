from pyuvm import uvm_subscriber


class ALUCoverage(uvm_subscriber):
    """Small functional coverage collector with no simulator-specific API."""

    def build_phase(self):
        self.control_bins = {control: 0 for control in range(10)}
        self.zero_cases = 0
        self.nonzero_cases = 0

    def write(self, tt) -> None:  # pyright: ignore[reportIncompatibleMethodOverride]
        self.control_bins[tt.alu_control] += 1
        if tt.result == 0:
            self.zero_cases += 1
        else:
            self.nonzero_cases += 1
