# Timing constraints for UTOSS RISC-V processor

# Create base clock constraint for 50MHz input
create_clock -name {CLOCK_50} -period 20.000 [get_ports {CLOCK_50}]

set_false_path -from [get_ports KEY[0]]
set_false_path -to   [get_ports KEY[0]]

set_false_path -from [get_ports LEDR]
set_false_path -to   [get_ports LEDR]

# Set input/output delays relative to the 5MHz clock
# Assume external signals are synchronized to the 5MHz domain
#set_input_delay -clock {clk_5mhz} -max 50.0 [get_ports {KEY[*]}]
#set_input_delay -clock {clk_5mhz} -min 10.0 [get_ports {KEY[*]}]

#set_output_delay -clock {clk_5mhz} -max 50.0 [get_ports {LEDR[*]}]
#set_output_delay -clock {clk_5mhz} -min -10.0 [get_ports {LEDR[*]}]

