# Verbatim copy of OpenROAD-flow-scripts flow/platforms/nangate45/global_connect.tcl @ 7a57dddc8
#   https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/blob/7a57dddc8427845f75a14bd975328ee8717a1c8b/flow/platforms/nangate45/global_connect.tcl
# Do not edit below the marker; re-sync from upstream instead (see README.md).
# ----8<---- upstream content starts here
# Global connections, made at floorplan right after the netlist is
# loaded (GLOBAL_CONNECT_TCL); the PDN scripts define the grids.
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {^VDD$} -power
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {^VDDPE$}
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {^VDDCE$}
add_global_connection -net {VSS} -inst_pattern {.*} -pin_pattern {^VSS$} -ground
add_global_connection -net {VSS} -inst_pattern {.*} -pin_pattern {^VSSE$}
