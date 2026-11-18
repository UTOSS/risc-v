# Timing constraints for the hardening `top` (core + memory_map)
#
# The clock period (ns) comes from the CLOCK_PERIOD environment variable so that it can be swept
# from the Makefile, e.g. `make pnr CLOCK_PERIOD=8`.

set clock_period 10.0
if {[info exists ::env(CLOCK_PERIOD)] && $::env(CLOCK_PERIOD) ne ""} {
  set clock_period $::env(CLOCK_PERIOD)
}

create_clock -name clk -period $clock_period [get_ports clk]

# budget 20% of the cycle for whatever sits outside of `top` on either side of its I/O
set io_delay [expr {$clock_period * 0.2}]
set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] [get_ports clk]]

set_input_delay  $io_delay -clock clk $non_clock_inputs
set_output_delay $io_delay -clock clk [all_outputs]

set_driving_cell -lib_cell BUF_X4 -pin Z $non_clock_inputs
set_load 3.898 [all_outputs]
