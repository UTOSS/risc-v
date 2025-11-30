# Timing constraints for UTOSS RISC-V processor

# Create base clock constraint for 50MHz input
create_clock -name {CLOCK_50} -period 20.000 [get_ports {CLOCK_50}]

# Create derived clock constraint for 5MHz divided clock
create_generated_clock -name {clk_5mhz} -source [get_ports {CLOCK_50}] -divide_by 10 [get_registers clk_5mhz]

# Set input/output delays relative to the 5MHz clock
# Assume external signals are synchronized to the 5MHz domain
set_input_delay -clock {clk_5mhz} -max 50.0 [get_ports {KEY[*]}]
set_input_delay -clock {clk_5mhz} -min 10.0 [get_ports {KEY[*]}]

set_output_delay -clock {clk_5mhz} -max 50.0 [get_ports {LEDR[*]}]
set_output_delay -clock {clk_5mhz} -min -10.0 [get_ports {LEDR[*]}]

# Create clock groups to avoid false timing paths between different clock domains
# (if you add more clocks later)
set_clock_groups -asynchronous -group {CLOCK_50} -group {clk_5mhz}
